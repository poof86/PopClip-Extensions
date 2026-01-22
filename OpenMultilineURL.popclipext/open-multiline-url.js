/**
 * PopClip Extension: Open Multiline URL
 *
 * This extension joins multi-line URLs (such as those copied from terminals
 * where line breaks interrupt the URL) and opens them in the default browser.
 *
 * The extension only appears when:
 * - Text contains a URL pattern (http:// or https://)
 * - The selected text spans multiple lines
 */

exports.action = (input) => {
  // Get the selected text and remove all line breaks
  const joinedUrl = input.text
    .replace(/[\r\n]+/g, '')  // Remove line breaks
    .trim();                   // Remove leading/trailing whitespace

  // Open the joined URL
  popclip.openUrl(joinedUrl);
};
