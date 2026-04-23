#!/usr/bin/env swift

import Cocoa
import WebKit

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
  body {
    display: flex;
    height: 100vh;
    -webkit-app-region: drag;
  }

  /* ── Editor pane ── */
  #editor-pane {
    width: 42%;
    display: flex;
    flex-direction: column;
    padding: 16px 12px 16px 16px;
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
    -webkit-app-region: no-drag;
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
    -webkit-app-region: no-drag;
  }
  /* Error pill — hidden unless there's an error */
  #status {
    font-size: 11px;
    font-weight: 500;
    color: rgba(255, 90, 90, 0.95);
    background: rgba(255, 60, 60, 0.18);
    border: 1px solid rgba(255, 90, 90, 0.3);
    border-radius: 20px;
    padding: 3px 11px;
    display: none;
  }
  #status.error { display: inline-block; }
  button {
    padding: 7px 20px;
    background: rgba(255, 255, 255, 0.15);
    color: rgba(255,255,255,0.92);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 20px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 500;
    transition: background 0.15s;
    white-space: nowrap;
    -webkit-app-region: no-drag;
  }
  button:hover { background: rgba(255, 255, 255, 0.26); }
  button:active { transform: scale(0.97); }

  /* ── Divider ── */
  #divider {
    width: 1px;
    background: rgba(255,255,255,0.08);
    margin: 16px 0;
    flex-shrink: 0;
  }

  /* ── Preview pane ── */
  #preview-pane {
    flex: 1;
    overflow: auto;
    padding: 28px;
    display: flex;
    align-items: flex-start;
    justify-content: center;
    -webkit-app-region: no-drag;
  }
  #preview-inner { max-width: 100%; }
  #output svg { max-width: 100%; height: auto; display: block; }
  #output:empty { display: none; }
  #error-msg {
    color: rgba(200, 60, 60, 0.9);
    font-family: 'SF Mono', Menlo, monospace;
    font-size: 12px;
    white-space: pre-wrap;
    line-height: 1.5;
  }
  #error-msg:empty { display: none; }
</style>
</head>
<body>

<div id="editor-pane">
  <textarea id="input" spellcheck="false"
    placeholder="Paste or type your Mermaid diagram here…"></textarea>
  <div id="toolbar">
    <span id="status"></span>
    <button onclick="copyAndClose()">Copy &amp; Close</button>
  </div>
</div>

<div id="divider"></div>

<div id="preview-pane">
  <div id="preview-inner">
    <div id="output"></div>
    <div id="error-msg"></div>
  </div>
</div>

<script type="module">
  import mermaid from 'https://esm.sh/mermaid';
  mermaid.initialize({ startOnLoad: false, theme: 'default', securityLevel: 'loose' });

  const input    = document.getElementById('input');
  const output   = document.getElementById('output');
  const errorMsg = document.getElementById('error-msg');
  const status   = document.getElementById('status');
  let debounceTimer = null, renderSeq = 0;

  async function render() {
    const text = input.value.trim();
    if (!text) {
      output.innerHTML = ''; errorMsg.textContent = '';
      status.textContent = ''; status.className = '';
      return;
    }
    const seq = ++renderSeq;
    try {
      const { svg } = await mermaid.render('mmd-' + seq, text);
      if (seq !== renderSeq) return;
      output.innerHTML = svg; errorMsg.textContent = '';
      status.textContent = ''; status.className = '';
    } catch (e) {
      if (seq !== renderSeq) return;
      output.innerHTML = '';
      errorMsg.textContent = e.message ?? String(e);
      status.textContent = 'Syntax error';
      status.className = 'error';
    }
  }

  input.addEventListener('input', () => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(render, 350);
  });

  window.setContent = function(text) { input.value = text; render(); };

  window.copyAndClose = function() {
    window.webkit.messageHandlers.editorAction.postMessage(
      { action: 'copy', text: input.value }
    );
  };

  if (typeof window.__initialContent__ === 'string') setContent(window.__initialContent__);
</script>
</body>
</html>
"""#

class MermaidEditor: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var window: NSWindow!
    var webView: WKWebView!
    let initialContent: String
    let sourcePath: String

    init(sourcePath: String) {
        self.sourcePath = sourcePath
        self.initialContent = (try? String(contentsOfFile: sourcePath, encoding: .utf8)) ?? ""
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        guard message.name == "editorAction",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        if action == "copy", let text = body["text"] as? String {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        cleanup(); NSApp.terminate(nil)
    }

    private func cleanup() { try? FileManager.default.removeItem(atPath: sourcePath) }

    func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        let jsonData = (try? JSONSerialization.data(withJSONObject: initialContent,
                                                    options: .fragmentsAllowed)) ?? Data("\"\"".utf8)
        let jsonStr  = String(data: jsonData, encoding: .utf8) ?? "\"\""
        let injection = WKUserScript(source: "window.__initialContent__ = \(jsonStr);",
                                     injectionTime: .atDocumentStart,
                                     forMainFrameOnly: true)
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(injection)
        config.userContentController.add(self, name: "editorAction")

        let rect = NSRect(x: 0, y: 0, width: 960, height: 620)
        window = NSWindow(contentRect: rect,
                          styleMask: [.borderless, .resizable],
                          backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.contentMinSize = NSSize(width: 500, height: 360)
        window.center()

        // Single clipping boundary
        let vfx = NSVisualEffectView(frame: rect)
        vfx.autoresizingMask = [.width, .height]
        vfx.material = .hudWindow
        vfx.blendingMode = .behindWindow
        vfx.state = .active
        vfx.wantsLayer = true
        vfx.layer?.cornerRadius = 20
        vfx.layer?.masksToBounds = true

        // WebView: transparent, clipped by VFX view — no extra cornerRadius
        webView = WKWebView(frame: rect, configuration: config)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")

        vfx.addSubview(webView)
        window.contentView = vfx

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in self?.cleanup(); NSApp.terminate(nil) }

        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        webView.loadHTMLString(html, baseURL: baseURL)

        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { self.window.invalidateShadow() }
        app.run()
    }
}

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: mermaid_editor <source.mmd>\n", stderr); exit(1)
}
MermaidEditor(sourcePath: CommandLine.arguments[1]).run()
