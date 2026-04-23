#!/bin/zsh

# Extend PATH so mmdc is found whether installed via Homebrew or npm
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:$PATH"

SCRIPT_DIR="${0:A:h}"
TEMP_FILE="${TMPDIR}mermaid_$(/usr/bin/uuidgen).svg"

# Strip fenced mermaid code block markers if present; otherwise use text as-is
INPUT=$(echo "$POPCLIP_TEXT" | perl -0777 -ne 'print /```mermaid\s*(.*?)(?:```|$)/s ? $1 : $_')

if command -v mmdc &>/dev/null; then
  echo "$INPUT" | mmdc -i - -o "$TEMP_FILE" -e svg || exit 1
else
  BASE64_STRING=$(echo -n "$INPUT" | /usr/bin/base64 -b 0 | tr '+/' '-_' | tr -d '=')
  /usr/bin/curl -sf "https://mermaid.ink/svg/${BASE64_STRING}" -o "$TEMP_FILE" || exit 1
fi

/usr/bin/swift "$SCRIPT_DIR/qlf.swift" "$TEMP_FILE" &>/dev/null &
