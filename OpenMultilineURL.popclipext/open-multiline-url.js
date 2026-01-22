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

export default async (input, options, context) => {
  // Get the selected text
  const text = input.text;

  // Validate we have text
  if (!text) {
    return null;
  }

  // Check if text contains line breaks (safety check, regex should handle this)
  if (!text.includes('\n') && !text.includes('\r')) {
    return null;
  }

  // Remove all line breaks and extra whitespace
  // This handles both Unix (\n) and Windows (\r\n) line endings
  const joinedUrl = text
    .replace(/[\r\n]+/g, '')  // Remove line breaks
    .trim();                   // Remove leading/trailing whitespace

  // Validate the result looks like a URL
  if (!joinedUrl.match(/^https?:\/\//i)) {
    return null;
  }

  // Open the joined URL
  popclip.openUrl(joinedUrl);
};
