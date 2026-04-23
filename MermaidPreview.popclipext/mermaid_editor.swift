#!/usr/bin/env swift

import Cocoa
import WebKit

private let htmlContent = #"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  html, body { height: 100%; }
  body {
    display: flex;
    font-family: -apple-system, system-ui, sans-serif;
    background: #1e1e1e;
    color: #ccc;
  }

  /* ── Editor pane ───────────────────────────────────────── */
  #editor-pane {
    width: 42%;
    min-width: 200px;
    display: flex;
    flex-direction: column;
    border-right: 1px solid #333;
  }
  textarea {
    flex: 1;
    padding: 16px;
    font-family: 'SF Mono', Menlo, 'Courier New', monospace;
    font-size: 13px;
    line-height: 1.6;
    background: #1e1e1e;
    color: #d4d4d4;
    border: none;
    resize: none;
    outline: none;
    tab-size: 2;
  }
  #toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 14px;
    background: #252526;
    border-top: 1px solid #333;
    gap: 8px;
  }
  #status {
    font-size: 11px;
    color: #888;
    min-width: 60px;
  }
  #status.error { color: #e05252; }
  #status.ok    { color: #4ec94e; }
  button {
    padding: 6px 18px;
    background: #0a84ff;
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    white-space: nowrap;
  }
  button:hover { background: #0060df; }
  button:active { transform: scale(0.97); }

  /* ── Preview pane ──────────────────────────────────────── */
  #preview-pane {
    flex: 1;
    overflow: auto;
    padding: 28px;
    background: #fff;
    display: flex;
    align-items: flex-start;
    justify-content: center;
  }
  #preview-inner { max-width: 100%; }
  #output svg { max-width: 100%; height: auto; display: block; }
  #error-msg {
    color: #c0392b;
    font-size: 12px;
    font-family: 'SF Mono', Menlo, monospace;
    white-space: pre-wrap;
    line-height: 1.5;
  }

  /* ── Loading spinner ───────────────────────────────────── */
  #loading {
    display: none;
    color: #aaa;
    font-size: 13px;
    padding: 12px;
  }
  #loading.visible { display: block; }
</style>
</head>
<body>

<div id="editor-pane">
  <textarea id="input" spellcheck="false" placeholder="Paste or type your Mermaid diagram here…"></textarea>
  <div id="toolbar">
    <span id="status">Ready</span>
    <button id="copy-btn" onclick="copyAndClose()">Copy &amp; Close</button>
  </div>
</div>

<div id="preview-pane">
  <div id="preview-inner">
    <div id="loading">Rendering…</div>
    <div id="output"></div>
    <div id="error-msg"></div>
  </div>
</div>

<script type="module">
import mermaid from 'https://esm.sh/mermaid';

mermaid.initialize({
  startOnLoad: false,
  theme: 'default',
  securityLevel: 'loose',
});

const input    = document.getElementById('input');
const output   = document.getElementById('output');
const errorMsg = document.getElementById('error-msg');
const status   = document.getElementById('status');
const loading  = document.getElementById('loading');

let debounceTimer = null;
let renderSeq = 0;

async function render() {
  const text = input.value.trim();
  if (!text) {
    output.innerHTML = '';
    errorMsg.textContent = '';
    setStatus('Ready', '');
    return;
  }

  const seq = ++renderSeq;
  loading.classList.add('visible');
  setStatus('Rendering…', '');

  try {
    const { svg } = await mermaid.render('mmd-' + seq, text);
    if (seq !== renderSeq) return;
    output.innerHTML = svg;
    errorMsg.textContent = '';
    setStatus('OK', 'ok');
  } catch (e) {
    if (seq !== renderSeq) return;
    output.innerHTML = '';
    errorMsg.textContent = e.message ?? String(e);
    setStatus('Error', 'error');
  } finally {
    if (seq === renderSeq) loading.classList.remove('visible');
  }
}

function setStatus(text, cls) {
  status.textContent = text;
  status.className = cls;
}

input.addEventListener('input', () => {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(render, 350);
});

// Called by Swift to send clipboard content back and close the window
window.copyAndClose = function() {
  window.webkit.messageHandlers.editorAction.postMessage({
    action: 'copy',
    text: input.value,
  });
};

// Called by Swift injection at document-start to seed the textarea
window.setContent = function(text) {
  input.value = text;
  render();
};

// Pick up content injected via WKUserScript before this module loaded
if (typeof window.__initialContent__ === 'string') {
  window.setContent(window.__initialContent__);
}
</script>
</body>
</html>
"""#

// ─────────────────────────────────────────────────────────────────────────────

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

    // MARK: WKScriptMessageHandler

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "editorAction",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String
        else { return }

        if action == "copy", let text = body["text"] as? String {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        cleanup()
        NSApp.terminate(nil)
    }

    // MARK: Lifecycle

    private func cleanup() {
        try? FileManager.default.removeItem(atPath: sourcePath)
    }

    func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        // Inject initial content as a global variable before any script runs,
        // so the ESM module can read it once mermaid.js has finished loading.
        let jsonData = (try? JSONSerialization.data(withJSONObject: initialContent)) ?? Data("\"\"".utf8)
        let jsonStr  = String(data: jsonData, encoding: .utf8) ?? "\"\""
        let injection = WKUserScript(
            source: "window.__initialContent__ = \(jsonStr);",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )

        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(injection)
        config.userContentController.add(self, name: "editorAction")

        let rect = NSRect(x: 0, y: 0, width: 980, height: 640)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mermaid Editor"
        window.center()
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.setContentMinSize(NSSize(width: 500, height: 360))

        // Clean up temp file if the window is closed without using Copy & Close
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.cleanup()
            NSApp.terminate(nil)
        }

        webView = WKWebView(frame: rect, configuration: config)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]
        window.contentView = webView

        // Use the temp directory as base URL so WebKit allows loading
        // external HTTPS resources (esm.sh) from the inline HTML.
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        webView.loadHTMLString(htmlContent, baseURL: baseURL)

        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

// ─────────────────────────────────────────────────────────────────────────────

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: mermaid_editor <source.mmd>\n", stderr)
    exit(1)
}

MermaidEditor(sourcePath: CommandLine.arguments[1]).run()
