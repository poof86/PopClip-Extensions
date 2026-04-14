/**
 * PopClip Extension: Type Text
 *
 * Types the selected text as individual keystrokes instead of pasting.
 * This is useful when the destination field blocks clipboard paste
 * (e.g., password confirmation fields, remote desktop sessions, VMs).
 *
 * The extension appears whenever text is selected.
 */

exports.action = (input) => {
  popclip.typeText(input.text);
};
