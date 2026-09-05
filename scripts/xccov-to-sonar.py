#!/usr/bin/env python3
"""Convert an .xcresult bundle's code coverage into Sonar's generic coverage XML.

Xcode reports coverage per file as aggregate percentages; Sonar wants one entry per executable
line. Only `xccov view --archive --file` gives per-line hit counts, so each file is queried in turn.

Usage: xccov-to-sonar.py <Result.xcresult> <output.xml> [path-prefix ...]
"""

import re
import subprocess
import sys
import json
from pathlib import Path
from xml.sax.saxutils import quoteattr

# "     12:      3" is line 12 hit 3 times; "*" marks a line that carries no code.
LINE = re.compile(r"^\s*(\d+):\s*(\*|\d+)")


def run(*args: str) -> str:
    return subprocess.run(args, capture_output=True, text=True, check=True).stdout


def covered_files(bundle: str, prefixes: list[str]) -> list[str]:
    """Absolute source paths in the report, restricted to the given repo-relative prefixes."""
    report = json.loads(run("xcrun", "xccov", "view", "--report", "--json", bundle))
    root = Path.cwd()
    paths = []
    for target in report.get("targets", []):
        for file in target.get("files", []):
            path = file.get("path", "")
            try:
                relative = Path(path).relative_to(root).as_posix()
            except ValueError:
                continue
            if not prefixes or any(relative.startswith(p) for p in prefixes):
                paths.append((relative, path))
    return sorted(set(paths))


def lines_for(bundle: str, absolute: str) -> list[tuple[int, bool]]:
    """Executable lines and whether each was hit. Non-executable lines are dropped."""
    output = run("xcrun", "xccov", "view", "--archive", "--file", absolute, bundle)
    result = []
    for row in output.splitlines():
        match = LINE.match(row)
        if match and match.group(2) != "*":
            result.append((int(match.group(1)), int(match.group(2)) > 0))
    return result


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2

    bundle, destination, prefixes = sys.argv[1], sys.argv[2], sys.argv[3:]
    files = covered_files(bundle, prefixes)
    # Failing loudly beats writing an empty report, which Sonar would read as a real 0%.
    if not files:
        print(f"No covered source files under {prefixes or ['(any path)']}", file=sys.stderr)
        return 1

    out = ['<?xml version="1.0" encoding="UTF-8"?>', '<coverage version="1">']
    executable = covered = 0
    for relative, absolute in files:
        lines = lines_for(bundle, absolute)
        if not lines:
            continue
        out.append(f"  <file path={quoteattr(relative)}>")
        for number, hit in lines:
            out.append(f'    <lineToCover lineNumber="{number}" covered="{str(hit).lower()}"/>')
            executable += 1
            covered += hit
        out.append("  </file>")
    out.append("</coverage>")
    Path(destination).write_text("\n".join(out) + "\n")

    share = 100.0 * covered / executable if executable else 0.0
    print(f"{len(files)} files, {covered}/{executable} executable lines covered ({share:.1f}%)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
