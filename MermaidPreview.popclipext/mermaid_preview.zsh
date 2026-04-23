#!/bin/zsh

# ── Debug logging ────────────────────────────────────────────────────────────
# Tail this file in Terminal to watch live:  tail -f ~/Library/Logs/MermaidPreview.log
LOGFILE="$HOME/Library/Logs/MermaidPreview.log"
exec >> "$LOGFILE" 2>&1
echo ""
echo "=== $(date) === mode: ${POPCLIP_OPTION_PREVIEWMODE:-quickview} ==="
set -x
# ─────────────────────────────────────────────────────────────────────────────

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:$PATH"

SCRIPT_DIR="${0:A:h}"

INPUT=$(echo "$POPCLIP_TEXT" | perl -0777 -ne 'print /```mermaid\s*(.*?)(?:```|$)/s ? $1 : $_')

if [[ "$POPCLIP_OPTION_PREVIEWMODE" == "quickeditor" ]]; then
  TEMP_SOURCE="${TMPDIR:-/tmp/}mermaid_$(/usr/bin/uuidgen).mmd"
  echo "$INPUT" > "$TEMP_SOURCE"
  /usr/bin/swift "$SCRIPT_DIR/mermaid_editor.swift" "$TEMP_SOURCE" >> "$LOGFILE" 2>&1 &
else
  TEMP_FILE="${TMPDIR:-/tmp/}mermaid_$(/usr/bin/uuidgen).svg"
  RENDERED=0
  if command -v mmdc &>/dev/null; then
    echo "$INPUT" | mmdc -i - -o "$TEMP_FILE" -e svg && RENDERED=1
  fi
  if [[ $RENDERED -eq 0 ]]; then
    BASE64_STRING=$(echo -n "$INPUT" | /usr/bin/base64 -b 0 | tr '+/' '-_' | tr -d '=')
    /usr/bin/curl -sf "https://mermaid.ink/svg/${BASE64_STRING}" -o "$TEMP_FILE" || exit 1
  fi
  /usr/bin/swift "$SCRIPT_DIR/qlf.swift" "$TEMP_FILE" >> "$LOGFILE" 2>&1 &
fi
