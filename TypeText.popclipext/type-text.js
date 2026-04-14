/**
 * PopClip Extension: Type Text
 *
 * Types the selected text as individual keystrokes instead of pasting.
 * This is useful when the destination field blocks clipboard paste
 * (e.g., password confirmation fields, remote desktop sessions, VMs).
 *
 * The extension appears whenever text is selected.
 */

// Maximum number of characters we are willing to type. Typing is character-
// by-character and uninterruptible, so a very large selection would be slow
// and almost certainly unintentional.
const MAX_CHARS = 1000;

exports.action = (input) => {
  // Strip non-printable ASCII control characters (0x00–0x1F) except for the
  // legitimate whitespace characters tab (\x09), newline (\x0A), and carriage
  // return (\x0D). Without this, characters such as \x01 (Ctrl+A / select all)
  // or \x1B (Escape) could fire unintended keyboard shortcuts in the target app.
  const sanitized = input.text.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');

  if (sanitized.length === 0) {
    popclip.showText('Nothing to type after removing control characters.');
    return;
  }

  if (sanitized.length > MAX_CHARS) {
    popclip.showText(`Too long to type (${sanitized.length} chars). Select ${MAX_CHARS} or fewer.`);
    return;
  }

  popclip.typeText(sanitized);
};
