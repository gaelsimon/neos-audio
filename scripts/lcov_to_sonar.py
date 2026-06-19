#!/usr/bin/env python3
"""Convert an lcov tracefile to SonarQube generic coverage XML.

Usage: lcov_to_sonar.py <in.lcov> <repo_root> <out.xml>
Paths are emitted relative to repo_root (what sonar.sources expects).
"""
import sys
import os
import xml.etree.ElementTree as ET


def main() -> int:
    lcov_path, repo_root, out_path = sys.argv[1], os.path.abspath(sys.argv[2]), sys.argv[3]
    coverage = ET.Element("coverage", version="1")
    current = None  # (file element)
    seen_lines: set[int] = set()

    with open(lcov_path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if line.startswith("SF:"):
                path = os.path.abspath(line[3:])
                if not path.startswith(repo_root):
                    current = None
                    continue
                rel = os.path.relpath(path, repo_root)
                current = ET.SubElement(coverage, "file", path=rel)
                seen_lines = set()
            elif line.startswith("DA:") and current is not None:
                number, hits = line[3:].split(",")[:2]
                num = int(number)
                if num in seen_lines:
                    continue
                seen_lines.add(num)
                ET.SubElement(current, "lineToCover",
                              lineNumber=str(num),
                              covered="true" if int(hits) > 0 else "false")

    ET.ElementTree(coverage).write(out_path, encoding="utf-8", xml_declaration=True)
    print(f"Wrote {out_path}: {len(coverage)} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
