# PopClip Extensions

Custom PopClip extensions for macOS.

## Extensions

### Type Text

Types clipboard content as individual keystrokes instead of pasting. Works in fields that block `Cmd+V`, such as password confirmation fields, remote desktops, and VMs.

[View Extension Details](./TypeText.popclipext/README.md)

**Installation:** Double-click the `TypeText.popclipext` directory to install.

---

### Terminal Copy

Intelligently detects and removes hard line breaks caused by selecting text in a terminal window, preserving intentional formatting like paragraphs, code blocks, and log output.

[View Extension Details](./TerminalCopy.popclipext/README.md)

**Installation:** Double-click the `TerminalCopy.popclipext` directory to install.

---

### Open Multiline URL

Opens URLs that span multiple lines by joining them into a single URL. Useful when copying URLs from terminal applications where line breaks are inserted.

[View Extension Details](./OpenMultilineURL.popclipext/README.md)

**Installation:** Double-click the `OpenMultilineURL.popclipext` directory to install.

## About PopClip

[PopClip](https://www.popclip.app/) is a macOS utility that appears when you select text, providing quick actions like copy, paste, search, and more. Extensions allow you to add custom actions.

## Development

These extensions are built using PopClip's JavaScript module system and AppleScript. See the [official documentation](https://www.popclip.app/dev/) for more information on creating extensions.

## License

MIT
