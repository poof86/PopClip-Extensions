#!/usr/bin/env swift

import Cocoa
import WebKit

// Sits above WKWebView at the top of the window; AppKit drags the window
// on mouseDown because mouseDownCanMoveWindow returns true.
class TitleDragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

private let html = #"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  html, body {
    height: 100%;
    background: transparent;
    font-family: -apple-system, system-ui, sans-serif;
    color: rgba(255,255,255,0.9);
  }
  body { height: 100%; }

  /* 28 px spacer under the native drag strip (both screens) */
  .drag-strip { height: 28px; flex-shrink: 0; }

  /* ═══════════════════ VIEWER SCREEN ═══════════════════ */
  #viewer {
    display: flex;
    flex-direction: column;
    height: 100%;
  }
  #viewer-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 8px 32px 24px;
    gap: 16px;
  }
  #v-output:empty { display: none; }
  #v-output svg { max-width: 100%; height: auto; display: block; }
  #v-error {
    color: rgba(200, 60, 60, 0.95);
    font-size: 12px;
    font-family: 'SF Mono', Menlo, monospace;
    white-space: pre-wrap;
    line-height: 1.6;
    background: rgba(255,255,255,0.88);
    padding: 14px 16px;
    border-radius: 10px;
    max-width: 100%;
  }
  #v-error:empty { display: none; }
  #viewer-footer {
    display: flex;
    align-items: center;
    gap: 20px;
  }
  #hint {
    font-size: 12px;
    color: rgba(255,255,255,0.55);
    user-select: none;
    text-shadow:
      0 1px 3px rgba(0,0,0,1),
      0 0 14px rgba(0,0,0,0.95);
  }

  /* ═══════════════════ EDITOR SCREEN ═══════════════════ */
  #editor {
    display: none;
    flex-direction: column;
    height: 100%;
  }
  #editor-main {
    display: flex;
    flex: 1;
    overflow: hidden;
  }
  #editor-pane {
    width: 42%;
    display: flex;
    flex-direction: column;
    padding: 0 12px 14px 16px;
    gap: 10px;
  }
  textarea {
    flex: 1;
    padding: 14px;
    font-family: 'SF Mono', Menlo, 'Courier New', monospace;
    font-size: 13px;
    line-height: 1.6;
    background: rgba(0, 0, 0, 0.28);
    color: rgba(255, 255, 255, 0.88);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 12px;
    resize: none;
    outline: none;
    tab-size: 2;
  }
  textarea:focus {
    border-color: rgba(255, 255, 255, 0.22);
    background: rgba(0, 0, 0, 0.35);
  }
  #toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 2px;
    flex-shrink: 0;
  }
  #e-status {
    font-size: 11px;
    font-weight: 500;
    color: rgba(255, 90, 90, 0.95);
    background: rgba(255, 60, 60, 0.18);
    border: 1px solid rgba(255, 90, 90, 0.3);
    border-radius: 20px;
    padding: 3px 11px;
    display: none;
  }
  #e-status.error { display: inline-block; }
  #divider {
    width: 1px;
    background: rgba(255,255,255,0.08);
    flex-shrink: 0;
  }
  #preview-pane {
    flex: 1;
    overflow: auto;
    padding: 24px;
    display: flex;
    align-items: flex-start;
    justify-content: center;
  }
  #e-output svg { max-width: 100%; height: auto; display: block; }
  #e-output:empty { display: none; }

  /* ═══════════════════ SHARED BUTTON ═══════════════════ */
  button {
    padding: 7px 20px;
    background: rgba(20, 20, 20, 0.65);
    color: rgba(255, 255, 255, 0.95);
    border: 1px solid rgba(255, 255, 255, 0.18);
    border-radius: 20px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 500;
    white-space: nowrap;
    transition: background 0.15s;
  }
  button:hover  { background: rgba(20, 20, 20, 0.82); }
  button:active { transform: scale(0.97); }
</style>
</head>
<body>

<!-- ── Viewer screen ── -->
<div id="viewer">
  <div class="drag-strip"></div>
  <div id="viewer-content">
    <div id="v-output"></div>
    <div id="v-error"></div>
    <div id="viewer-footer">
      <p id="hint">Click outside or Esc to close</p>
      <button onclick="switchToEditor()">Edit</button>
    </div>
  </div>
</div>

<!-- ── Editor screen (hidden until Edit is clicked) ── -->
<div id="editor">
  <div class="drag-strip"></div>
  <div id="editor-main">
    <div id="editor-pane">
      <textarea id="input" spellcheck="false"
        placeholder="Paste or type your Mermaid diagram here…"></textarea>
      <div id="toolbar">
        <span id="e-status"></span>
        <button onclick="copyAndClose()">Copy &amp; Close</button>
      </div>
    </div>
    <div id="divider"></div>
    <div id="preview-pane">
      <div id="e-output"></div>
    </div>
  </div>
</div>

<script type="module">
  import mermaid from 'https://esm.sh/mermaid';
  mermaid.initialize({ startOnLoad: false, theme: 'default', securityLevel: 'loose' });

  let currentContent = '';
  let editorSeq = 0;
  let debounceTimer = null;
  let isEditing = false;

  const vOutput = document.getElementById('v-output');
  const vError  = document.getElementById('v-error');
  const eOutput = document.getElementById('e-output');
  const eStatus = document.getElementById('e-status');
  const input   = document.getElementById('input');
  const viewer  = document.getElementById('viewer');
  const editor  = document.getElementById('editor');

  function bridge(msg) {
    window.webkit.messageHandlers.bridge.postMessage(msg);
  }

  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') bridge({ type: 'close' });
    if (e.key === ' ' && !isEditing) bridge({ type: 'close' });
  });

  // ── Viewer ──────────────────────────────────────────────────────────────────

  window.renderContent = async function(text) {
    currentContent = text;
    try {
      const { svg } = await mermaid.render('mmd-view', text.trim());
      vOutput.innerHTML = svg;
      vError.textContent = '';
      requestAnimationFrame(() => {
        const svgEl = vOutput.querySelector('svg');
        if (!svgEl) return;
        const { width, height } = svgEl.getBoundingClientRect();
        bridge({ type: 'resize', width, height });
      });
    } catch (e) {
      vOutput.innerHTML = '';
      vError.textContent = e.message ?? String(e);
    }
  };

  window.switchToEditor = function() {
    isEditing = true;
    viewer.style.display = 'none';
    editor.style.display = 'flex';
    input.value = currentContent;
    renderEditor();
    bridge({ type: 'edit' });
  };

  // ── Editor ──────────────────────────────────────────────────────────────────

  async function renderEditor() {
    const text = input.value.trim();
    if (!text) {
      eOutput.innerHTML = '';
      eStatus.textContent = ''; eStatus.className = '';
      return;
    }
    const seq = ++editorSeq;
    try {
      await mermaid.parse(text);             // throws on bad syntax — no bomb SVG
      const { svg } = await mermaid.render('mmd-edit-' + seq, text);
      if (seq !== editorSeq) return;
      eOutput.innerHTML = svg;
      eStatus.textContent = ''; eStatus.className = '';
    } catch (e) {
      if (seq !== editorSeq) return;
      eOutput.innerHTML = '';
      eStatus.textContent = 'Syntax error'; eStatus.className = 'error';
    }
  }

  input.addEventListener('input', () => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(renderEditor, 350);
  });

  window.copyAndClose = function() {
    bridge({ type: 'copy', text: input.value });
  };

  if (typeof window.__content__ === 'string') renderContent(window.__content__);
</script>
</body>
</html>
"""#

class MermaidPreview: NSObject, WKScriptMessageHandler {
    var window: NSWindow!
    var webView: WKWebView!
    let content: String
    let sourcePath: String
    var globalMonitor: Any?

    init(sourcePath: String) {
        self.sourcePath = sourcePath
        self.content = (try? String(contentsOfFile: sourcePath, encoding: .utf8)) ?? ""
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        switch type {
        case "close":
            close()
        case "edit":
            if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window.styleMask.insert(.resizable)
                self.window.contentMinSize = NSSize(width: 500, height: 360)
                self.window.setContentSize(NSSize(width: 960, height: 620))
                self.window.center()
            }
        case "copy":
            if let text = body["text"] as? String {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            close()
        case "resize":
            guard let w = body["width"] as? CGFloat,
                  let h = body["height"] as? CGFloat else { return }
            resizeToFit(svgWidth: w, svgHeight: h)
        default: break
        }
    }

    private func resizeToFit(svgWidth: CGFloat, svgHeight: CGFloat) {
        // 28 drag strip + 16 gap + 36 footer row + 24 bottom pad + 8 top pad
        let chrome: CGFloat = 112
        let hPad:   CGFloat = 64
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let newW = min(max(svgWidth  + hPad,    360), screen.width  * 0.85)
        let newH = min(max(svgHeight + chrome,  260), screen.height * 0.85)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window.setContentSize(NSSize(width: newW, height: newH))
            self.window.center()
        }
    }

    private func close() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        cleanup()
        NSApp.terminate(nil)
    }

    private func cleanup() { try? FileManager.default.removeItem(atPath: sourcePath) }

    func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let jsonData = (try? JSONSerialization.data(withJSONObject: content,
                                                    options: .fragmentsAllowed)) ?? Data("\"\"".utf8)
        let jsonStr  = String(data: jsonData, encoding: .utf8) ?? "\"\""
        let injection = WKUserScript(source: "window.__content__ = \(jsonStr);",
                                     injectionTime: .atDocumentStart,
                                     forMainFrameOnly: true)
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(injection)
        config.userContentController.add(self, name: "bridge")

        let rect = NSRect(x: 0, y: 0, width: 680, height: 480)

        window = NSWindow(contentRect: rect,
                          styleMask: [.titled, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.center()
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        let vfx = NSVisualEffectView(frame: rect)
        vfx.autoresizingMask = [.width, .height]
        vfx.material = .hudWindow
        vfx.blendingMode = .behindWindow
        vfx.state = .active

        webView = WKWebView(frame: rect, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        vfx.addSubview(webView)

        // Native drag strip: intercepts mouseDown in the top 28 px so
        // AppKit can move the window; events below it reach the webview.
        let dragH    = CGFloat(28)
        let dragView = TitleDragView(frame: NSRect(x: 0, y: rect.height - dragH,
                                                   width: rect.width, height: dragH))
        dragView.autoresizingMask = [.width, .minYMargin]
        vfx.addSubview(dragView)

        window.contentView = vfx

        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        webView.loadHTMLString(html, baseURL: baseURL)

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self else { return }
            if !self.window.frame.contains(NSEvent.mouseLocation) { self.close() }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in self?.close() }

        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: mermaid_preview <source.mmd>\n", stderr); exit(1)
}
MermaidPreview(sourcePath: CommandLine.arguments[1]).run()
