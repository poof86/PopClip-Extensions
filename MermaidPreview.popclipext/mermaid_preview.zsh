#!/bin/zsh

# ── Debug logging (uncomment to enable) ──────────────────────────────────────
# Tail this file in Terminal to watch live:  tail -f ~/Library/Logs/MermaidPreview.log
#LOGFILE="$HOME/Library/Logs/MermaidPreview.log"
#exec >> "$LOGFILE" 2>&1
#echo ""
#echo "=== $(date) ==="
#set -x
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="${0:A:h}"

# Strip fenced mermaid code block markers if present; otherwise use text as-is
INPUT=$(printf '%s\n' "$POPCLIP_TEXT" | perl -0777 -ne 'print /```mermaid\s*(.*?)(?:```|$)/s ? $1 : $_')

TEMP_SOURCE="${TMPDIR:-/tmp/}mermaid_$(/usr/bin/uuidgen).mmd"
printf '%s\n' "$INPUT" > "$TEMP_SOURCE"

/usr/bin/swift "$SCRIPT_DIR/mermaid_preview.swift" "$TEMP_SOURCE" > /dev/null 2>&1 &
