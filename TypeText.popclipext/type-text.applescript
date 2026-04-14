-- Get clipboard content as text, error if not available
try
    set rawText to the clipboard as text
on error
    error "Clipboard does not contain text"
end try

if rawText is "" then error "Clipboard is empty"

-- Abort if too long — keystroke is uninterruptible, so a very large clipboard
-- would be slow and almost certainly a mistake.
set textLength to length of rawText
if textLength > 1000 then
    display notification "Too long to type (" & textLength & " chars). Copy 1000 or fewer." with title "Type"
    return
end if

-- Strip non-printable ASCII control characters (0x00–0x1F except tab/newline/CR,
-- and 0x7F). Without this, characters such as 0x01 (Ctrl+A) or 0x1B (Escape)
-- could trigger unintended keyboard shortcuts in the target app.
-- quoted form of safely escapes any special characters before passing to the shell.
set theText to do shell script "printf '%s' " & quoted form of rawText & " | LC_ALL=C tr -d '\\000-\\010\\013\\014\\016-\\037\\177'"

if theText is "" then error "Nothing to type after removing control characters"

-- Type the text using System Events keystroke.
-- This simulates real keyboard input and works even in fields that block Cmd+V.
tell application "System Events"
    keystroke theText
end tell
