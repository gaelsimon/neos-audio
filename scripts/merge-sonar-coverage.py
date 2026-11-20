#!/usr/bin/env python3
"""Merge Sonar generic coverage reports into one: a line is covered when any report covers it.

The Mac and the iPhone builds compile different files, and different branches of the files they
share, so neither report alone says what the tests reach.

Usage: merge-sonar-coverage.py <output.xml> <report.xml> [<report.xml> ...]
"""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import quoteattr


def merged(reports: list[str]) -> dict[str, dict[int, bool]]:
    """Per file, each executable line and whether any report covers it."""
    files: dict[str, dict[int, bool]] = {}
    for report in reports:
        for file in ET.parse(report).getroot().iter("file"):
            lines = files.setdefault(file.get("path"), {})
            for line in file.iter("lineToCover"):
                number = int(line.get("lineNumber"))
                lines[number] = lines.get(number, False) or line.get("covered") == "true"
    return files


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2

    destination, reports = sys.argv[1], sys.argv[2:]
    files = merged(reports)
    # Failing loudly beats writing an empty report, which Sonar would read as a real 0%.
    if not files:
        print(f"No coverage in {reports}", file=sys.stderr)
        return 1

    out = ['<?xml version="1.0" encoding="UTF-8"?>', '<coverage version="1">']
    executable = covered = 0
    for path in sorted(files):
        out.append(f"  <file path={quoteattr(path)}>")
        for number in sorted(files[path]):
            hit = files[path][number]
            out.append(f'    <lineToCover lineNumber="{number}" covered="{str(hit).lower()}"/>')
            executable += 1
            covered += hit
        out.append("  </file>")
    out.append("</coverage>")
    Path(destination).write_text("\n".join(out) + "\n")

    share = 100.0 * covered / executable
    print(f"{len(files)} files, {covered}/{executable} executable lines covered ({share:.1f}%)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
