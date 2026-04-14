#!/bin/bash
# PopClip Extension: Type Text
#
# Types clipboard content as individual keystrokes using AppleScript's
# System Events keystroke command. Works in fields that block Cmd+V paste
# (e.g. password confirmation fields, remote desktops, VMs).

set -euo pipefail

MAX_CHARS=1000

# Read clipboard content
CLIPBOARD=$(pbpaste)

# Bail silently if clipboard is empty
if [ -z "$CLIPBOARD" ]; then
    exit 1
fi

# Strip non-printable ASCII control characters (0x00–0x1F) except for the
# legitimate whitespace chars: tab (0x09), newline (0x0A), carriage return (0x0D).
# Without this, characters such as 0x01 (Ctrl+A) or 0x1B (Escape) could fire
# unintended keyboard shortcuts via keystroke in the target app.
SANITIZED=$(printf '%s' "$CLIPBOARD" | LC_ALL=C tr -d '\000-\010\013\014\016-\037\177')

if [ -z "$SANITIZED" ]; then
    exit 1
fi

# Abort if too long — keystroke is uninterruptible and character-by-character,
# so a very large clipboard would be slow and almost certainly a mistake.
LENGTH=${#SANITIZED}
if [ "$LENGTH" -gt "$MAX_CHARS" ]; then
    osascript -e "display notification \"Too long to type ($LENGTH chars). Copy $MAX_CHARS or fewer.\" with title \"Type\""
    exit 0
fi

# Write sanitized text to a temp file so we can pass it to AppleScript without
# any risk of shell injection — the user data never gets embedded in the script.
TMPFILE=$(mktemp /tmp/popclip-typetext-XXXXXX)
printf '%s' "$SANITIZED" > "$TMPFILE"
trap 'rm -f "$TMPFILE"' EXIT

# Type the text using System Events keystroke.
# keystroke simulates real keyboard input — it works even in fields that
# block clipboard paste.
osascript <<EOF
set theFile to POSIX file "$TMPFILE"
set theText to (read theFile as «class utf8»)
tell application "System Events"
    keystroke theText
end tell
EOF
