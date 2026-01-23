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
    // Get lengths of lines that are likely full-width (> 50 chars)
    let lens = lines.map(l => l.length).filter(n => n > 50);
    if (lens.length === 0) return null;

    // Find the most common line length (terminal width)
    let counts = {};
    lens.forEach(n => counts[n] = (counts[n] || 0) + 1);
    let sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]);
    return sorted.length ? parseInt(sorted[0][0], 10) : null;
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
      let nextLine = lines[i + 1] || '';
      let isLastLine = i === lines.length - 1;

      // If line is at terminal width (within 3 chars tolerance) and not last line
      if (!isLastLine && Math.abs(line.length - width) <= 3) {
        // Check if next line looks like a list item or new sentence
        let nextIsListItem = /^\s*[-*•]\s/.test(nextLine);
        let nextStartsNewSentence = /^[A-Z]/.test(nextLine.trim()) && /[.!?]$/.test(line);

        if (nextIsListItem || nextStartsNewSentence) {
          // Keep the line break
          result.push(line + '\n');
        } else {
          // This is likely a terminal wrap, join without line break
          // Add space unless line ends with URL-like character or hyphen
          if (/[\/\-_=%&?]$/.test(line)) {
            result.push(line); // No space for URL/word continuations
          } else {
            result.push(line + ' '); // Space for prose
          }
        }
      } else {
        // Keep this line break (short line or last line)
        result.push(line);
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
