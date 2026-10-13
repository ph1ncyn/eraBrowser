//
//  ExtensionPageWindow.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import AppKit
import WebKit

/// A window showing an extension page (e.g. its options page).
/// Extension pages need the context's own web view configuration, so they don't open as regular tabs.
enum ExtensionPageWindow {
    private static var windows: [NSWindow] = []

    static func show(url: URL, context: WKWebExtensionContext) {
        guard let configuration = context.webViewConfiguration else { return }

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 760, height: 560), configuration: configuration)
        webView.isInspectable = true
        webView.load(URLRequest(url: url))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(context.webExtension.displayName ?? "Extension") Settings"
        window.contentView = webView
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)

        windows.append(window)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            windows.removeAll { $0 === window }
        }
    }
}
