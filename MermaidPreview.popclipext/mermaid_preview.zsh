#!/bin/zsh

# ── Debug logging ────────────────────────────────────────────────────────────
# Tail this file in Terminal to watch live:  tail -f ~/Library/Logs/MermaidPreview.log
LOGFILE="$HOME/Library/Logs/MermaidPreview.log"
exec >> "$LOGFILE" 2>&1
echo ""
echo "=== $(date) === mode: ${POPCLIP_OPTION_PREVIEWMODE:-quickview} ==="
set -x
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="${0:A:h}"

# Strip fenced mermaid code block markers if present; otherwise use text as-is
INPUT=$(echo "$POPCLIP_TEXT" | perl -0777 -ne 'print /```mermaid\s*(.*?)(?:```|$)/s ? $1 : $_')

TEMP_SOURCE="${TMPDIR:-/tmp/}mermaid_$(/usr/bin/uuidgen).mmd"
echo "$INPUT" > "$TEMP_SOURCE"

if [[ "$POPCLIP_OPTION_PREVIEWMODE" == "quickeditor" ]]; then
  /usr/bin/swift "$SCRIPT_DIR/mermaid_editor.swift" "$TEMP_SOURCE" >> "$LOGFILE" 2>&1 &
else
  /usr/bin/swift "$SCRIPT_DIR/mermaid_viewer.swift" "$TEMP_SOURCE" >> "$LOGFILE" 2>&1 &
fi
