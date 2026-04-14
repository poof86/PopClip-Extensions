/**
 * PopClip Extension: Type Text
 *
 * Types the clipboard content as individual keystrokes instead of pasting.
 * This is useful when the destination field blocks clipboard paste
 * (e.g., password confirmation fields, remote desktop sessions, VMs).
 *
 * The extension appears whenever the clipboard contains text (requirements:
 * "paste"). Trigger PopClip normally (text selection or keyboard shortcut),
 * then click Type — the clipboard content will be typed at the cursor.
 */

// Maximum number of characters we are willing to type. Typing is character-
// by-character and uninterruptible, so very large clipboard content would be
// slow and almost certainly unintentional.
const MAX_CHARS = 1000;

exports.action = () => {
  const clipboardText = pasteboard.text;

  if (!clipboardText || clipboardText.length === 0) {
    popclip.showText('Clipboard is empty.');
    return;
  }

  // Strip non-printable ASCII control characters (0x00–0x1F) except for the
  // legitimate whitespace characters tab (\x09), newline (\x0A), and carriage
  // return (\x0D). Without this, characters such as \x01 (Ctrl+A / select all)
  // or \x1B (Escape) could fire unintended keyboard shortcuts in the target app.
  const sanitized = clipboardText.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');

  if (sanitized.length === 0) {
    popclip.showText('Nothing to type after removing control characters.');
    return;
  }

  if (sanitized.length > MAX_CHARS) {
    popclip.showText(`Too long to type (${sanitized.length} chars). Copy ${MAX_CHARS} or fewer.`);
    return;
  }

  popclip.typeText(sanitized);
};
