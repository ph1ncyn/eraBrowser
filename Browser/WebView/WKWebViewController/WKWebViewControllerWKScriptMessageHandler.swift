//
//  WKWebViewControllerWKScriptMessageHandler.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 3/24/25.
//
import WebKit

/// Handles messages forwarded by `WebViewScriptMessageRouter` for this controller's web view
extension WKWebViewController {
    func handleScriptMessage(_ message: WKScriptMessage) {
        switch message.name {
        case "hoverURL":
            handleHoverURL(message.body)
        case "middleClickLink":
            handleMiddleClickLink(message.body)
        default:
            break
        }
    }

    func handleHoverURL(_ body: Any) {
        guard UserDefaults.standard.bool(forKey: "show_hover_url"),
              let url = body as? String, !url.isEmpty else { return }
        self.coordinator?.setHoverURL(to: url)
    }

    func handleMiddleClickLink(_ body: Any) {
        guard let urlString = body as? String, let url = URL(string: urlString) else { return }
        self.coordinator?.openLinkInNewTabAction(url)
    }
}
