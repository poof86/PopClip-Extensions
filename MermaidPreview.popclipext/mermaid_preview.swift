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
    position: relative;
    overflow: hidden;
    cursor: grab;
    user-select: none;
    touch-action: none;
  }
  #viewer-content.dragging { cursor: grabbing; }
  #v-output { position: absolute; transform-origin: 0 0; }
  #v-output:empty { display: none; }
  #v-output svg { display: block; }
  #v-error {
    position: absolute;
    top: 50%; left: 50%;
    transform: translate(-50%, -50%);
    color: rgba(200, 60, 60, 0.95);
    font-size: 12px;
    font-family: 'SF Mono', Menlo, monospace;
    white-space: pre-wrap;
    line-height: 1.6;
    background: rgba(255,255,255,0.88);
    padding: 14px 16px;
    border-radius: 10px;
    max-width: calc(100% - 32px);
  }
  #v-error:empty { display: none; }
  #viewer-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 24px 16px;
    flex-shrink: 0;
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
  </div>
  <div id="viewer-footer">
    <p id="hint">Scroll to zoom · Drag to pan · Dbl-click to reset · Esc to close</p>
    <button onclick="switchToEditor()">Edit</button>
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

  const vOutput      = document.getElementById('v-output');
  const vError       = document.getElementById('v-error');
  const viewerContent= document.getElementById('viewer-content');
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

  // ── Viewer pan/zoom ──────────────────────────────────────────────────────────

  let naturalW = 0, naturalH = 0;
  const pz = { scale: 1, tx: 0, ty: 0 };
  let vDragging = false, vDragSX = 0, vDragSY = 0, vDragSTX = 0, vDragSTY = 0;

  function applyPZ() {
    vOutput.style.transform = `translate(${pz.tx}px,${pz.ty}px) scale(${pz.scale})`;
  }

  function fitToViewport() {
    if (!naturalW || !naturalH) return;
    const cW = viewerContent.clientWidth;
    const cH = viewerContent.clientHeight;
    if (!cW || !cH) return;
    // Window sizing already adds padding around the SVG; no extra pad needed here.
    const s = Math.min(1, cW / naturalW, cH / naturalH);
    pz.scale = s;
    pz.tx = (cW - naturalW * s) / 2;
    pz.ty = (cH - naturalH * s) / 2;
    applyPZ();
  }

  viewerContent.addEventListener('wheel', e => {
    e.preventDefault();
    const rect = viewerContent.getBoundingClientRect();
    const mx = e.clientX - rect.left;
    const my = e.clientY - rect.top;
    const factor = e.deltaY < 0 ? 1.1 : 1 / 1.1;
    const newS = Math.max(0.05, Math.min(10, pz.scale * factor));
    const ratio = newS / pz.scale;
    pz.tx = mx - (mx - pz.tx) * ratio;
    pz.ty = my - (my - pz.ty) * ratio;
    pz.scale = newS;
    applyPZ();
  }, { passive: false });

  // Pointer events + setPointerCapture so AppKit's isMovableByWindowBackground
  // can't swallow the drag before JS sees it.
  viewerContent.addEventListener('pointerdown', e => {
    if (e.button !== 0) return;
    vDragging = true;
    vDragSX = e.clientX; vDragSY = e.clientY;
    vDragSTX = pz.tx;    vDragSTY = pz.ty;
    viewerContent.classList.add('dragging');
    viewerContent.setPointerCapture(e.pointerId);
    e.preventDefault();
  });
  viewerContent.addEventListener('pointermove', e => {
    if (!vDragging) return;
    pz.tx = vDragSTX + (e.clientX - vDragSX);
    pz.ty = vDragSTY + (e.clientY - vDragSY);
    applyPZ();
  });
  viewerContent.addEventListener('pointerup', e => {
    if (!vDragging) return;
    vDragging = false;
    viewerContent.classList.remove('dragging');
    viewerContent.releasePointerCapture(e.pointerId);
  });
  viewerContent.addEventListener('pointercancel', () => {
    vDragging = false;
    viewerContent.classList.remove('dragging');
  });
  viewerContent.addEventListener('dblclick', fitToViewport);
  // ResizeObserver is more reliable than window 'resize' for WKWebView reflows.
  new ResizeObserver(() => { if (!isEditing) fitToViewport(); }).observe(viewerContent);

  // ── Viewer ──────────────────────────────────────────────────────────────────

  window.renderContent = async function(text) {
    currentContent = text;
    try {
      const { svg } = await mermaid.render('mmd-view', text.trim());
      vOutput.style.transform = '';
      vOutput.innerHTML = svg;
      vError.textContent = '';
      await new Promise(r => requestAnimationFrame(r));
      const svgEl = vOutput.querySelector('svg');
      if (svgEl) {
        const rect = svgEl.getBoundingClientRect();
        naturalW = rect.width;
        naturalH = rect.height;
        // Tell Swift to size the window to match the diagram's aspect ratio,
        // then fit the SVG into whatever viewport we end up with.
        bridge({ type: 'resize', width: naturalW, height: naturalH });
        fitToViewport();
      }
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
        // Non-diagram chrome: 28 px drag strip + ~59 px footer (padding + button).
        let chromeH: CGFloat = 87
        // Use the editor dimensions as the maximum bounding box.
        let maxW: CGFloat = 960
        let maxH: CGFloat = 620
        let minW: CGFloat = 320
        let minH: CGFloat = 260

        // Scale the diagram to fill the available area at its natural aspect ratio.
        let aspect   = svgWidth / max(svgHeight, 1)
        let availH   = maxH - chromeH          // max content height
        var contentW = maxW
        var contentH = contentW / aspect
        if contentH > availH {
            contentH = availH
            contentW = contentH * aspect
        }

        let newW = max(minW, contentW).rounded()
        let newH = max(minH, contentH + chromeH).rounded()
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
    
    @objc func handleWindowDrag(_ gesture: NSPanGestureRecognizer) {
        // 1. We must use the contentView as the reference point for the location.
        // This is the only way to get the click position from the gesture.
        guard let contentView = window.contentView else { return }
        let locationInView = gesture.location(in: contentView)
        
        // 2. THE GATEKEEPER:
        // We check if the click hit the webView.
        // We check the webView's frame in the contentView's coordinate space.
        if let webView = contentView.subviews.first(where: { $0 is WKWebView }),
           webView.frame.contains(locationInView) {
            
            // If the click is inside the webView, we do nothing.
            // This allows the webView to handle its own buttons/text.
            // We reset the translation so it doesn't "drift"
            gesture.setTranslation(.zero, in: contentView)
            return
        }

        // 3. THE DRAG:
        // If we are here, the click was on the background/vfx/drag-strip.
        // We use the native macOS drag method.
        // We use the current event from the application.
        if let event = NSApp.currentEvent {
            window.performDrag(with: event)
        }
        
        // 4. Safety Reset
        gesture.setTranslation(.zero, in: contentView)
    }

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
        //let dragH    = CGFloat(28)
        //let dragView = TitleDragView(frame: NSRect(x: 0, y: rect.height - dragH,
        //                                           width: rect.width, height: dragH))
        //dragView.autoresizingMask = [.width, .minYMargin]
        //vfx.addSubview(dragView)

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
        
        let windowDragGesture = NSPanGestureRecognizer(target: self, action: #selector(handleWindowDrag(_:)))
        window.contentView?.addGestureRecognizer(windowDragGesture)

        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: mermaid_preview <source.mmd>\n", stderr); exit(1)
}
MermaidPreview(sourcePath: CommandLine.arguments[1]).run()
