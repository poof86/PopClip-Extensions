/**
 * PopClip Extension: Open Multiline URL
 *
 * This extension joins multi-line URLs (such as those copied from terminals
 * where line breaks interrupt the URL) and opens them in the default browser.
 */

export default async (input, options, context) => {
  // Get the selected text
  const text = input.text;

  // Remove all line breaks and extra whitespace
  // This handles both Unix (\n) and Windows (\r\n) line endings
  const joinedUrl = text
    .replace(/[\r\n]+/g, '')  // Remove line breaks
    .trim();                   // Remove leading/trailing whitespace

  // Open the joined URL
  popclip.openUrl(joinedUrl);
};
