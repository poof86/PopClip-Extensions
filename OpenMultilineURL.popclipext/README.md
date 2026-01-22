# Open Multiline URL

A PopClip extension that opens URLs spanning multiple lines by joining them into a single URL before opening.

## Problem

When copying URLs from terminal applications or text editors, line breaks are often inserted into the URL, making it impossible to open with the standard "Open URL" action. For example:

```
https://example.com/very/long/path/
that/continues/on/next/line
```

The native PopClip URL action would fail because it treats this as invalid due to the line break.

## Solution

This extension:
1. **Only appears** when you select text that contains a URL pattern (`http://` or `https://`) spanning multiple lines
2. Removes all line breaks from the selection
3. Opens the resulting URL in your default browser

**Smart Detection:** The extension won't interfere with the native PopClip URL opener. It only shows when:
- The selected text contains `http://` or `https://`
- The text spans multiple lines (contains line breaks)
- This ensures single-line URLs continue to use the native handler

## Icon

The extension displays a link icon with a plus symbol (⛓️➕) to distinguish it from the native URL opener, indicating it will join the lines together.

## Installation

1. Download or clone this repository
2. Double-click the `OpenMultilineURL.popclipext` directory
3. PopClip will prompt you to install the extension

## Usage

1. Select a URL that spans multiple lines (e.g., in Terminal)
2. The "Open Multiline URL" action will appear in the PopClip menu
3. Click it to open the joined URL

## Examples

### Multi-line URL (Extension Appears)

**Selected text:**
```
https://github.com/pilotmoon/PopClip-Extensions/
blob/master/README.md
```

**Result:** The "Open Multiline URL" action appears with the link-plus icon. Clicking it opens `https://github.com/pilotmoon/PopClip-Extensions/blob/master/README.md` correctly in your browser.

### Single-line URL (Extension Hidden)

**Selected text:**
```
https://github.com/pilotmoon/PopClip-Extensions/blob/master/README.md
```

**Result:** The extension doesn't appear. Use the native PopClip "Open URL" action instead.

## Requirements

- PopClip version 2021.5 or later (build 3895+)
- macOS

## Technical Details

- **Language:** JavaScript
- **Icon:** Custom PNG (link with plus symbol)
- **Detection Pattern:** `(?s)(https?://.*[\r\n].*)` - Matches URLs containing line breaks
- **Requirements:** Text selection with URL pattern and line breaks

## License

MIT
