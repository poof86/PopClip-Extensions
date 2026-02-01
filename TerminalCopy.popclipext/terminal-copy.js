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
 * Calculate the display width of a string in terminal columns.
 * Wide characters (CJK, emoji, etc.) count as 2 columns.
 */
function displayWidth(str) {
  let width = 0;
  for (const char of str) {
    const code = char.codePointAt(0);
    // Wide characters: CJK, emoji, fullwidth forms, etc.
    if (code >= 0x1100 && (
      code <= 0x115F ||                      // Hangul Jamo
      code === 0x2329 || code === 0x232A ||  // Angle brackets
      (code >= 0x2E80 && code <= 0x3247) ||  // CJK Radicals, Kangxi, etc.
      (code >= 0x3250 && code <= 0x4DBF) ||  // CJK, extensions
      (code >= 0x4E00 && code <= 0xA4C6) ||  // CJK Unified Ideographs
      (code >= 0xA960 && code <= 0xA97C) ||  // Hangul Jamo Extended-A
      (code >= 0xAC00 && code <= 0xD7A3) ||  // Hangul Syllables
      (code >= 0xF900 && code <= 0xFAFF) ||  // CJK Compatibility Ideographs
      (code >= 0xFE10 && code <= 0xFE1F) ||  // Vertical forms
      (code >= 0xFE30 && code <= 0xFE6F) ||  // CJK Compatibility Forms
      (code >= 0xFF00 && code <= 0xFF60) ||  // Fullwidth Forms
      (code >= 0xFFE0 && code <= 0xFFE6) ||  // Fullwidth symbols
      (code >= 0x1F300 && code <= 0x1F64F) || // Misc Symbols, Emoticons
      (code >= 0x1F680 && code <= 0x1F6FF) || // Transport/Map symbols
      (code >= 0x1F900 && code <= 0x1F9FF) || // Supplemental Symbols
      (code >= 0x1FA00 && code <= 0x1FA6F) || // Chess, extended-A
      (code >= 0x1FA70 && code <= 0x1FAFF) || // Symbols extended-A
      (code >= 0x20000 && code <= 0x2FFFD) || // CJK Extension B-F
      (code >= 0x30000 && code <= 0x3FFFD)    // CJK Extension G+
    )) {
      width += 2;
    } else if (code < 0x20 || (code >= 0x7F && code < 0xA0)) {
      // Control characters have 0 width
      width += 0;
    } else {
      width += 1;
    }
  }
  return width;
}

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

  // Get display widths of lines that are likely full-width (> 50 columns)
  const lengths = lines.map(l => displayWidth(l)).filter(n => n > 50);

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
    // Get display widths of lines including trailing spaces (raw terminal width)
    let widths = lines.map(l => displayWidth(l)).filter(n => n > 50);
    if (widths.length === 0) return null;

    // Find the most common display width (terminal width)
    let counts = {};
    widths.forEach(n => counts[n] = (counts[n] || 0) + 1);
    let sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]);
    return sorted.length ? parseInt(sorted[0][0], 10) : null;
  }

  /**
   * Check if a line is actually wrapped (content fills the width)
   * vs just padded with trailing spaces (content ended early)
   */
  function isWrappedLine(line, width) {
    const rawWidth = displayWidth(line);
    const trimmedWidth = displayWidth(line.trimEnd());

    // Line must be at terminal width (within tolerance)
    if (Math.abs(rawWidth - width) > 3) {
      return false;
    }

    // If trimmed width is also close to width, content fills the line → wrapped
    // If trimmed width is much shorter, it's padded → not wrapped
    const paddingAmount = rawWidth - trimmedWidth;

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
