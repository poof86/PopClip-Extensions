# Terminal Copy PopClip Extension

A PopClip extension that intelligently detects and fixes hard line breaks caused by selecting text in a terminal.

## Features

- **Smart Line Break Detection**: Automatically detects terminal width-based line wrapping
- **URL Handling**: Removes all line breaks from multi-line URLs
- **Intelligent Processing**: Preserves intentional formatting such as:
  - Paragraph breaks (double line breaks)
  - Code blocks and indented code
  - Log output with timestamps
  - List items
  - New sentences

## How It Works

The extension only appears when you select text that contains line breaks (multiple lines). When activated, it:

1. Detects if the text is a URL spanning multiple lines → removes all breaks
2. For other text, analyzes the line lengths to deduce terminal width
3. Intelligently removes artificial line breaks while preserving intentional formatting
4. Copies the cleaned text to your clipboard

## Installation

1. Download the `TerminalCopy.popclipext` folder
2. Double-click to install in PopClip
3. The "Copy +" action will appear when selecting multi-line text

## Use Cases

Perfect for copying:
- Terminal output that wrapped at the terminal width
- Documentation or text from narrow terminal windows
- URLs that span multiple lines
- Command output and logs (preserves log formatting)

## Based On

This extension is based on Better Touch Tool clipboard processing logic, adapted for PopClip.
