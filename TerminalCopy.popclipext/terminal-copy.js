/**
 * PopClip Extension: Terminal Copy
 *
 * This extension detects and fixes hard line breaks caused by terminal text selections.
 * It intelligently removes line breaks that are artifacts of terminal width wrapping
 * while preserving intentional formatting like paragraphs, code blocks, and lists.
 *
 * The extension only appears when:
 * - Text is selected
 * - Terminal-width line breaks are detected (common line lengths)
 *
 * Based on Better Touch Tool clipboard processing logic.
 */

/**
 * Detect if text has terminal-width line breaks
 */
function hasTerminalLineBreaks(text) {
  // Must have line breaks
  if (!text || !/[\r\n]/.test(text)) {
    return false;
  }

  // If it's a URL spanning multiple lines, that counts
  if (/^https?:\/\//.test(text.trim()) && /[\r\n]/.test(text)) {
    return true;
  }

  // Check for common line lengths (terminal wrapping)
  const lines = text.split(/\n/);

  // Need at least 2 lines
  if (lines.length < 2) {
    return false;
  }

  // Get lengths of lines that are likely full-width (> 50 chars)
  const lengths = lines.map(l => l.length).filter(n => n > 50);

  // Need at least 2 substantial lines
  if (lengths.length < 2) {
    return false;
  }

  // Count occurrences of each length (with ±3 tolerance)
  const buckets = {};
  lengths.forEach(len => {
    // Group similar lengths together (within 3 chars)
    const bucket = Math.round(len / 3) * 3;
    buckets[bucket] = (buckets[bucket] || 0) + 1;
  });

  // Check if we have at least 2 lines with similar lengths
  const maxCount = Math.max(...Object.values(buckets));
  return maxCount >= 2;
}

/**
 * Process text to remove terminal line breaks
 */
function processTerminalText(clipboardContentString) {
  // If it's a URL that spans multiple lines, just remove all breaks
  if (/^https?:\/\//.test(clipboardContentString.trim())) {
    return clipboardContentString.replace(/\n/g, '');
  }

  // For other content, detect and remove terminal width breaks
  function deduceWidth(lines) {
    // Get lengths of lines including trailing spaces (raw terminal width)
    let lens = lines.map(l => l.length).filter(n => n > 50);
    if (lens.length === 0) return null;

    // Find the most common line length (terminal width)
    let counts = {};
    lens.forEach(n => counts[n] = (counts[n] || 0) + 1);
    let sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]);
    return sorted.length ? parseInt(sorted[0][0], 10) : null;
  }

  /**
   * Check if a line is actually wrapped (content fills the width)
   * vs just padded with trailing spaces (content ended early)
   */
  function isWrappedLine(line, width) {
    const rawLength = line.length;
    const trimmedLength = line.trimEnd().length;

    // Line must be at terminal width (within tolerance)
    if (Math.abs(rawLength - width) > 3) {
      return false;
    }

    // If trimmed length is also close to width, content fills the line → wrapped
    // If trimmed length is much shorter, it's padded → not wrapped
    const paddingAmount = rawLength - trimmedLength;

    // Allow small amount of trailing space (1-2 chars) as tolerance
    // but significant padding indicates line ended naturally
    return paddingAmount <= 2;
  }

  function looksLikeCode(lines) {
    // More comprehensive code detection
    let codePatterns = lines.filter(l =>
      /[{};=><]/.test(l) ||           // Code symbols
      /^\s*(def|class|import|from|function|const|let|var|if|for|while)\b/.test(l) || // Keywords
      /^\s{4,}/.test(l) ||            // Indented code blocks
      /```/.test(l)                   // Markdown code fences
    ).length;
    return codePatterns / lines.length > 0.3;
  }

  function looksLikeLogOutput(lines) {
    // Detect log-like patterns (timestamps, log levels, etc.)
    let logPatterns = lines.filter(l =>
      /^\d{4}-\d{2}-\d{2}/.test(l) ||     // ISO timestamps
      /^\[\d{2}:\d{2}:\d{2}\]/.test(l) || // [HH:MM:SS]
      /^(INFO|WARN|ERROR|DEBUG):/i.test(l) || // Log levels
      /^>\s/.test(l)                       // Quoted lines (common in logs)
    ).length;
    return logPatterns / lines.length > 0.4;
  }

  // Split on double+ line breaks (preserve paragraph breaks)
  const paragraphs = clipboardContentString.split(/\n\n+/);

  let processed = paragraphs.map(block => {
    let lines = block.split('\n');

    // Single line, nothing to do
    if (lines.length === 1) return block;

    // If it looks like code or logs, preserve formatting
    if (looksLikeCode(lines) || looksLikeLogOutput(lines)) return block;

    let width = deduceWidth(lines);

    // Can't determine width, return as-is
    if (!width) return block;

    let result = [];
    for (let i = 0; i < lines.length; i++) {
      let line = lines[i];
      let trimmedLine = line.trimEnd(); // Remove terminal padding
      let nextLine = lines[i + 1] || '';
      let isLastLine = i === lines.length - 1;

      // Check if this line is truly wrapped (content fills width, not just padded)
      if (!isLastLine && isWrappedLine(line, width)) {
        // Check if next line looks like a list item or new sentence
        let nextTrimmed = nextLine.trimEnd();
        let nextIsListItem = /^\s*[-*•]\s/.test(nextTrimmed);
        let nextStartsNewSentence = /^[A-Z]/.test(nextTrimmed.trim()) && /[.!?]$/.test(trimmedLine);

        if (nextIsListItem || nextStartsNewSentence) {
          // Keep the line break
          result.push(trimmedLine + '\n');
        } else {
          // This is likely a terminal wrap, join without line break
          // Add space unless line ends with URL-like character or hyphen
          if (/[\/\-_=%&?]$/.test(trimmedLine)) {
            result.push(trimmedLine); // No space for URL/word continuations
          } else {
            result.push(trimmedLine + ' '); // Space for prose
          }
        }
      } else {
        // Keep this line break (short line, padded line, or last line)
        result.push(trimmedLine);
        if (!isLastLine) result.push('\n');
      }
    }
    return result.join('');
  });

  return processed.join('\n\n');
}

/**
 * Population function - dynamically determines if action should appear
 */
exports.actions = (input) => {
  // Only show action if terminal line breaks are detected
  if (!hasTerminalLineBreaks(input.text)) {
    return []; // No action - extension won't appear
  }

  // Return the action definition
  return [{
    title: 'Copy +',
    code: () => {
      const processed = processTerminalText(input.text);
      popclip.copyText(processed);
    }
  }];
};
