# Type Text

A PopClip extension that types your clipboard content as individual keystrokes instead of pasting it. Useful anywhere that blocks `Cmd+V`.

## Problem

Some fields actively block clipboard paste:

- **Password confirmation fields** — many websites prevent pasting to force you to re-type
- **Remote desktops and VMs** — clipboard sharing isn't always available
- **Kiosk or locked-down apps** — paste may be deliberately disabled

In these cases, `Cmd+V` does nothing, and your only option is to type the content by hand.

## Solution

This extension simulates real keyboard input using macOS's System Events, character by character. Because it mimics actual typing rather than a paste operation, it bypasses paste restrictions.

**Workflow:**

1. Copy the text you want to type (`Cmd+C`)
2. Click in the destination field
3. Select any nearby text (or use PopClip's keyboard shortcut) to trigger PopClip
4. Click **Type** — the keyboard icon in the PopClip bar
5. The clipboard content is typed into the field

## Safety

- **Control characters stripped** — non-printable ASCII characters (e.g. `Ctrl+A`, `Escape`) are removed before typing to prevent unintended keyboard shortcuts firing in the target app
- **1000 character limit** — typing is uninterruptible; if your clipboard exceeds 1000 characters the extension aborts with a notification rather than starting an unstoppable keystroke flood
- **Clipboard-only** — the extension only appears when the clipboard contains text (`requirements: paste`), so it never shows up unnecessarily

## Installation

1. Download or clone this repository
2. Double-click the `TypeText.popclipext` directory
3. PopClip will prompt you to install the extension

## Requirements

- PopClip version 2021.5 or later (build 3895+)
- macOS (Accessibility permissions required for System Events — PopClip requests these automatically)

## Technical Details

- **Language:** AppleScript
- **Icon:** SF Symbol `keyboard`
- **Trigger:** Clipboard contains text (`requirements: paste`)
- **Typing mechanism:** `System Events keystroke` — genuine keyboard simulation, not a paste

## License

MIT
