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
  html, body { height: 100%; background: #fff; }
  body {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100%;
    padding: 28px;
  }
  #output svg { max-width: 100%; height: auto; display: block; }
  #error {
    color: #c0392b;
    font-family: 'SF Mono', Menlo, monospace;
    font-size: 12px;
    white-space: pre-wrap;
    line-height: 1.5;
  }
  #close-btn {
    position: fixed;
    top: 10px; right: 12px;
    background: rgba(0,0,0,0.1);
    border: none;
    border-radius: 50%;
    width: 26px; height: 26px;
    font-size: 14px;
    cursor: pointer;
    color: #555;
    display: flex; align-items: center; justify-content: center;
  }
  #close-btn:hover { background: rgba(0,0,0,0.2); }
</style>
</head>
<body>
<button id="close-btn" title="Close (Esc)"
  onclick="window.webkit.messageHandlers.action.postMessage('close')">✕</button>
<div>
  <div id="output"></div>
  <div id="error"></div>
</div>
<script type="module">
  import mermaid from 'https://esm.sh/mermaid';
  mermaid.initialize({ startOnLoad: false, theme: 'default', securityLevel: 'loose' });

  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' || e.key === ' ') {
      window.webkit.messageHandlers.action.postMessage('close');
    }
  });

  window.renderContent = async function(text) {
    try {
      const { svg } = await mermaid.render('mmd-view', text.trim());
      document.getElementById('output').innerHTML = svg;
    } catch (e) {
      document.getElementById('error').textContent = e.message ?? String(e);
    }
  };

  if (typeof window.__content__ === 'string') {
    renderContent(window.__content__);
  }
</script>
</body>
</html>
"""#

class MermaidViewer: NSObject, WKScriptMessageHandler {
    var window: NSWindow!
    var webView: WKWebView!
    let content: String
    let sourcePath: String

    init(sourcePath: String) {
        self.sourcePath = sourcePath
        self.content = (try? String(contentsOfFile: sourcePath, encoding: .utf8)) ?? ""
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        if message.name == "action" {
            cleanup()
            NSApp.terminate(nil)
        }
    }

    private func cleanup() {
        try? FileManager.default.removeItem(atPath: sourcePath)
    }

    func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let jsonData = (try? JSONSerialization.data(withJSONObject: content, options: .fragmentsAllowed)) ?? Data("\"\"".utf8)
        let jsonStr = String(data: jsonData, encoding: .utf8) ?? "\"\""
        let injection = WKUserScript(
            source: "window.__content__ = \(jsonStr);",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )

        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(injection)
        config.userContentController.add(self, name: "action")

        let rect = NSRect(x: 0, y: 0, width: 720, height: 540)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mermaid Preview"
        window.center()
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.cleanup()
            NSApp.terminate(nil)
        }

        webView = WKWebView(frame: rect, configuration: config)
        webView.autoresizingMask = [.width, .height]
        window.contentView = webView

        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        webView.loadHTMLString(html, baseURL: baseURL)

        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: mermaid_viewer <source.mmd>\n", stderr)
    exit(1)
}

MermaidViewer(sourcePath: CommandLine.arguments[1]).run()
