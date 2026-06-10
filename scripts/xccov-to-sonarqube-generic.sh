#!/usr/bin/env bash
# Usage: ./scripts/xccov-to-sonarqube-generic.sh <path/to/file.xcresult>
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <path/to/file.xcresult>" >&2
  exit 1
fi

XCRESULT="$1"

xccov_to_generic() {
  echo '<coverage version="1">'
  xcrun xccov view --archive --file-list "$XCRESULT" \
    | while read -r file_path; do
        printf '  <file path="%s">\n' "$(printf '%s' "$file_path" | sed -e 's/&/\&amp;/g' -e 's/"/\&quot;/g')"
        xcrun xccov view --archive --file "$file_path" "$XCRESULT" \
          | awk '
              /^[[:space:]]*[0-9]+:[[:space:]]+[0-9*]+/ {
                line=$1
                sub(":", "", line)
                hits=$2
                covered = (hits != "0") ? "true" : "false"
                printf "    <lineToCover lineNumber=\"%s\" covered=\"%s\"/>\n", line, covered
              }
            '
        echo '  </file>'
      done
  echo '</coverage>'
}

xccov_to_generic
