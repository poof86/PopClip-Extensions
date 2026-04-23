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
    /* entire window is draggable; no-drag set on interactive regions below */
    -webkit-app-region: drag;
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
  #output {
    -webkit-app-region: no-drag;
  }
  #output:empty { display: none; }
  #output svg {
    max-width: 100%;
    height: auto;
    display: block;
  }
  #error {
    -webkit-app-region: no-drag;
    color: rgba(200, 60, 60, 0.95);
    font-family: 'SF Mono', Menlo, monospace;
    font-size: 12px;
    white-space: pre-wrap;
    line-height: 1.6;
    background: rgba(255,255,255,0.88);
    padding: 14px 16px;
    border-radius: 10px;
    max-width: 100%;
  }
  #error:empty { display: none; }
  #hint {
    font-size: 12px;
    font-weight: 400;
    color: rgba(255,255,255,0.35);
    letter-spacing: 0.01em;
    user-select: none;
    -webkit-app-region: drag;
  }
</style>
</head>
<body>
<div id="output"></div>
<div id="error"></div>
<p id="hint">Click outside or press Esc to close</p>
<script type="module">
  import mermaid from 'https://esm.sh/mermaid';
  mermaid.initialize({ startOnLoad: false, theme: 'default', securityLevel: 'loose' });

  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' || e.key === ' ')
      window.webkit.messageHandlers.action.postMessage('close');
  });

  window.renderContent = async function(text) {
    try {
      const { svg } = await mermaid.render('mmd-view', text.trim());
      document.getElementById('output').innerHTML = svg;
      document.getElementById('error').textContent = '';

      requestAnimationFrame(() => {
        const svgEl = document.querySelector('#output svg');
        if (!svgEl) return;
        const { width, height } = svgEl.getBoundingClientRect();
        window.webkit.messageHandlers.resize.postMessage({ width, height });
      });
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
    var vfx: NSVisualEffectView!
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
        switch message.name {
        case "action":
            close()
        case "resize":
            guard let body = message.body as? [String: Any],
                  let w = body["width"] as? CGFloat,
                  let h = body["height"] as? CGFloat else { return }
            resizeToFit(svgWidth: w, svgHeight: h)
        default: break
        }
    }

    private func resizeToFit(svgWidth: CGFloat, svgHeight: CGFloat) {
        let htmlPad: CGFloat = 64   // 32px each side in HTML
        let hintRow: CGFloat = 44   // hint text + gap
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1440,height:900)
        let newW = min(max(svgWidth  + htmlPad, 360), screen.width  * 0.85)
        let newH = min(max(svgHeight + htmlPad + hintRow, 260), screen.height * 0.85)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window.setContentSize(NSSize(width: newW, height: newH))
            self.window.center()
            self.window.invalidateShadow()
        }
    }

    private func close() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        cleanup(); NSApp.terminate(nil)
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
        config.userContentController.add(self, name: "action")
        config.userContentController.add(self, name: "resize")

        let rect = NSRect(x: 0, y: 0, width: 680, height: 480)

        window = NSWindow(contentRect: rect,
                          styleMask: [.borderless],
                          backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.center()

        // Glass layer — this is the single clipping boundary
        vfx = NSVisualEffectView(frame: rect)
        vfx.autoresizingMask = [.width, .height]
        vfx.material = .hudWindow
        vfx.blendingMode = .behindWindow
        vfx.state = .active
        vfx.wantsLayer = true
        vfx.layer?.cornerRadius = 20
        vfx.layer?.masksToBounds = true

        // WebView: transparent, clipped by the VFX view above — no extra cornerRadius
        webView = WKWebView(frame: rect, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")

        vfx.addSubview(webView)
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
        // Recompute shadow from actual rendered (rounded) pixels
        DispatchQueue.main.async { self.window.invalidateShadow() }
        app.run()
    }
}

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: mermaid_viewer <source.mmd>\n", stderr); exit(1)
}
MermaidViewer(sourcePath: CommandLine.arguments[1]).run()
