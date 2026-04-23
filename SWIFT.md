# Swift interactive window patterns

Decisions and gotchas for building floating glass panels with WKWebView on macOS,
extracted from the MermaidPreview extension.

---

## Window setup

Use `.titled` combined with `.fullSizeContentView`. Do **not** use `.borderless`.

```swift
window = NSWindow(contentRect: rect,
                  styleMask: [.titled, .fullSizeContentView],
                  backing: .buffered, defer: false)
window.titleVisibility = .hidden
window.titlebarAppearsTransparent = true
window.isOpaque = false
window.backgroundColor = .clear
window.hasShadow = true
```

Why `.titled` instead of `.borderless`:
- `.borderless` gives a rectangular shadow regardless of content shape.
  macOS computes the shadow from the window's defined shape, not from what is
  drawn inside it. With `.hudWindow` visual effect blending, borderless windows
  never get the correct pill-shaped shadow.
- `.titled` + `.fullSizeContentView` lets content fill the entire frame while
  macOS still treats it as a regular titled window — correct rounded-corner
  shadow included, no native title bar visible.

Add `.resizable` later at runtime if the window needs to become resizable after
a mode switch:

```swift
window.styleMask.insert(.resizable)
window.contentMinSize = NSSize(width: 500, height: 360)
```

---

## Glass effect

```swift
let vfx = NSVisualEffectView(frame: rect)
vfx.autoresizingMask = [.width, .height]
vfx.material = .hudWindow    // frosted glass, works in both light and dark mode
vfx.blendingMode = .behindWindow
vfx.state = .active          // must be .active, not .followsWindowActiveState
window.contentView = vfx
```

Do **not** set `cornerRadius` or `masksToBounds` on the visual effect view or
on the web view. The native window already clips to its shape; a second clip
boundary causes rendering artefacts (white corners outside the rounded shape).

---

## WKWebView transparency

```swift
webView = WKWebView(frame: rect, configuration: config)
webView.autoresizingMask = [.width, .height]
webView.setValue(false, forKey: "drawsBackground")
vfx.addSubview(webView)
```

- `isOpaque` is read-only on macOS 26 SDK — do not set it.
- `backgroundColor = .clear` on the web view is also unreliable on newer SDKs.
- `setValue(false, forKey: "drawsBackground")` is the only reliable way to make
  the WKWebView transparent so the visual effect shows through.
- In HTML, set `background: transparent` on both `html` and `body`.

---

## Native window dragging

CSS `-webkit-app-region: drag` shows the correct cursor but does not actually
move the window on macOS. Use a native `NSView` overlay instead:

```swift
class TitleDragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}
```

Place it above WKWebView in the view hierarchy, covering only the drag strip:

```swift
let dragH    = CGFloat(28)
let dragView = TitleDragView(frame: NSRect(x: 0, y: rect.height - dragH,
                                           width: rect.width, height: dragH))
dragView.autoresizingMask = [.width, .minYMargin]  // full-width, pinned to top
vfx.addSubview(dragView)                           // added after webView
```

`window.isMovableByWindowBackground = true` must also be set — it tells AppKit
to honour `mouseDownCanMoveWindow` from subviews.

Events outside the drag strip fall through to WKWebView (buttons, textareas,
scroll, etc.) because `TitleDragView` only covers 28 px. The HTML reserves
matching space with a `<div class="drag-strip">` spacer so content is not
obscured.

---

## JS ↔ Swift message bridge

Register handlers before loading HTML:

```swift
let config = WKWebViewConfiguration()
config.userContentController.add(self, name: "bridge")
```

Post from JavaScript:

```javascript
window.webkit.messageHandlers.bridge.postMessage({ type: 'close' })
```

Receive in Swift (`WKScriptMessageHandler`):

```swift
func userContentController(_ ucc: WKUserContentController,
                            didReceive message: WKScriptMessage) {
    guard let body = message.body as? [String: Any],
          let type = body["type"] as? String else { return }
    switch type {
    case "close":  close()
    case "resize": ...
    default: break
    }
}
```

One named handler with a `type` field keeps the bridge surface small and easy
to extend. Multiple named handlers work too but fragment the protocol.

---

## Injecting content before the ESM module loads

WKWebView loads ES modules asynchronously. A `WKUserScript` injected at
`.atDocumentStart` runs before the module resolves, so the module's init code
can read a `window.__content__` variable that Swift pre-seeded:

```swift
// JSON-encode the string so it is safe to inline into a <script> block.
// .fragmentsAllowed is required — without it, JSONSerialization refuses to
// encode a top-level String (only Array/Dictionary are accepted by default).
let jsonData = (try? JSONSerialization.data(withJSONObject: content,
                                            options: .fragmentsAllowed))
               ?? Data("\"\"".utf8)
let jsonStr  = String(data: jsonData, encoding: .utf8) ?? "\"\""

let injection = WKUserScript(source: "window.__content__ = \(jsonStr);",
                             injectionTime: .atDocumentStart,
                             forMainFrameOnly: true)
config.userContentController.addUserScript(injection)
```

In the module:

```javascript
if (typeof window.__content__ === 'string') renderContent(window.__content__);
```

---

## Click-outside-to-close

`NSEvent.addGlobalMonitorForEvents` fires even when the app is not focused,
making it the right tool for a floating panel that should dismiss on any outside
click:

```swift
globalMonitor = NSEvent.addGlobalMonitorForEvents(
    matching: [.leftMouseDown, .rightMouseDown]
) { [weak self] _ in
    guard let self else { return }
    if !self.window.frame.contains(NSEvent.mouseLocation) { self.close() }
}
```

Remove the monitor explicitly before `NSApp.terminate` — leaked monitors keep
firing after the window is gone:

```swift
private func close() {
    if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
    cleanup()
    NSApp.terminate(nil)
}
```

When the window transitions from a light-dismiss panel to an editor that the
user interacts with, remove the monitor so outside clicks no longer close it.

---

## App activation policy

```swift
app.setActivationPolicy(.accessory)  // no Dock icon, no app switcher entry
app.activate(ignoringOtherApps: true)
```

`.accessory` is appropriate for transient floating panels launched by another
app (e.g. a PopClip extension). `.regular` shows a Dock icon, which is
disruptive for short-lived tool windows.

The `activate(ignoringOtherApps: true)` call ensures the window becomes key
and receives keyboard events even though it was launched from a background
process.

---

## Mermaid.js via esm.sh

```javascript
import mermaid from 'https://esm.sh/mermaid';
mermaid.initialize({ startOnLoad: false, theme: 'default', securityLevel: 'loose' });
```

Always call `mermaid.parse(text)` **before** `mermaid.render(...)`. In v10+,
`render` writes a bomb-emoji SVG directly into the DOM when the syntax is
invalid, and it cannot be suppressed. `parse` throws instead, letting you show
a clean error state:

```javascript
try {
  await mermaid.parse(text);          // throws on bad syntax
  const { svg } = await mermaid.render('unique-id', text);
  output.innerHTML = svg;
} catch (e) {
  output.innerHTML = '';              // never show the bomb SVG
  statusPill.className = 'error';
}
```

Each call to `mermaid.render` must use a unique `id` argument — mermaid tracks
previously rendered IDs internally and will error on duplicates. Use a
monotonically incrementing sequence number as a suffix.

---

## Text readability over a glass background

Text rendered directly over a blurred background can be illegible depending on
what is behind the window. A heavy layered `text-shadow` works on any colour:

```css
#hint {
  color: rgba(255,255,255,0.55);
  text-shadow:
    0 1px 3px rgba(0,0,0,1),
    0 0 14px rgba(0,0,0,0.95);
}
```

For buttons, a dark semi-transparent background with a subtle border is
consistently legible:

```css
button {
  background: rgba(20, 20, 20, 0.65);
  color: rgba(255, 255, 255, 0.95);
  border: 1px solid rgba(255, 255, 255, 0.18);
}
```

---

## Temp file hygiene

Write content to a unique temp file, pass the path to the Swift process, and
delete it when the window closes:

```swift
private func cleanup() {
    try? FileManager.default.removeItem(atPath: sourcePath)
}
```

In the shell script:

```zsh
TEMP="${TMPDIR:-/tmp/}mermaid_$(/usr/bin/uuidgen).mmd"
echo "$INPUT" > "$TEMP"
/usr/bin/swift script.swift "$TEMP" &
```

Use `${TMPDIR:-/tmp/}` — `TMPDIR` is empty in the PopClip subprocess
environment even though it is set in a normal shell session.
