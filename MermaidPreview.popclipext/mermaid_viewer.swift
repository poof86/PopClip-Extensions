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
  }
  body {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 100%;
    padding: 32px;
    gap: 16px;
  }
  #output svg {
    max-width: 100%;
    height: auto;
    display: block;
    filter: drop-shadow(0 2px 12px rgba(0,0,0,0.4));
  }
  #error {
    color: rgba(255, 110, 110, 0.95);
    font-family: 'SF Mono', Menlo, monospace;
    font-size: 12px;
    white-space: pre-wrap;
    line-height: 1.6;
    background: rgba(0,0,0,0.25);
    padding: 14px 16px;
    border-radius: 10px;
    border: 1px solid rgba(255,255,255,0.08);
    max-width: 100%;
  }
  #hint {
    font-size: 11px;
    color: rgba(255,255,255,0.25);
    letter-spacing: 0.02em;
    user-select: none;
  }
</style>
</head>
<body>
<div id="output"></div>
<div id="error"></div>
<p id="hint">Click outside or press Esc to close</p>
<script type="module">
  import mermaid from 'https://esm.sh/mermaid';
  mermaid.initialize({ startOnLoad: false, theme: 'dark', securityLevel: 'loose' });

  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' || e.key === ' ')
      window.webkit.messageHandlers.action.postMessage('close');
  });

  window.renderContent = async function(text) {
    try {
      const { svg } = await mermaid.render('mmd-view', text.trim());
      document.getElementById('output').innerHTML = svg;
      document.getElementById('error').textContent = '';
    } catch (e) {
      document.getElementById('error').textContent = e.message ?? String(e);
    }
  };

  if (typeof window.__content__ === 'string') renderContent(window.__content__);
</script>
</body>
</html>
"""#

class MermaidViewer: NSObject, WKScriptMessageHandler {
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
        close()
    }

    private func close() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        cleanup()
        NSApp.terminate(nil)
    }

    private func cleanup() {
        try? FileManager.default.removeItem(atPath: sourcePath)
    }

    func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let jsonData = (try? JSONSerialization.data(withJSONObject: content,
                                                    options: .fragmentsAllowed)) ?? Data("\"\"".utf8)
        let jsonStr = String(data: jsonData, encoding: .utf8) ?? "\"\""
        let injection = WKUserScript(source: "window.__content__ = \(jsonStr);",
                                     injectionTime: .atDocumentStart,
                                     forMainFrameOnly: true)
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(injection)
        config.userContentController.add(self, name: "action")

        let size = NSSize(width: 680, height: 520)
        let rect = NSRect(origin: .zero, size: size)

        window = NSWindow(contentRect: rect,
                          styleMask: [.borderless],
                          backing: .buffered,
                          defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.center()

        // Glass background layer
        let vfx = NSVisualEffectView(frame: rect)
        vfx.autoresizingMask = [.width, .height]
        vfx.material = .hudWindow
        vfx.blendingMode = .behindWindow
        vfx.state = .active
        vfx.wantsLayer = true
        vfx.layer?.cornerRadius = 20
        vfx.layer?.masksToBounds = true

        // Transparent WebView renders on top of glass
        webView = WKWebView(frame: rect, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.setValue(false, forKey: "drawsBackground")

        vfx.addSubview(webView)
        window.contentView = vfx

        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        webView.loadHTMLString(html, baseURL: baseURL)

        // Click outside → close
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
    fputs("Usage: mermaid_viewer <source.mmd>\n", stderr); exit(1)
}
MermaidViewer(sourcePath: CommandLine.arguments[1]).run()
