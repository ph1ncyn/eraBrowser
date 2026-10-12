//
//  SharedWebViewConfiguration.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/2/25.
//

import WebKit

/// Shared configuration for WKWebView instances
class SharedWebViewConfiguration {
    // Singleton to ensure a single shared configuration across tabs
    static let shared = SharedWebViewConfiguration()

    // Shared configuration with cache, cookies, and other settings
    let configuration: WKWebViewConfiguration

    /// Configuration for No-Trace windows: same settings, scripts and content blockers,
    /// but backed by a non-persistent data store so nothing is written to disk.
    /// It is a copy, so the persistent `configuration` is never modified.
    private(set) lazy var noTraceConfiguration: WKWebViewConfiguration = {
        let noTraceConfiguration = configuration.copy() as! WKWebViewConfiguration
        noTraceConfiguration.websiteDataStore = .nonPersistent()
        return noTraceConfiguration
    }()

    private init() {
        configuration = WKWebViewConfiguration()

        configuration.allowsAirPlayForMediaPlayback = true
        configuration.websiteDataStore = .default()
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Configure content blockers
        do {
            if let adawayURL = Bundle.main.url(forResource: "adaway", withExtension: "json") {
                let contentBlockers = try String(contentsOf: adawayURL, encoding: .utf8)
                WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "BrowserContentBlockers", encodedContentRuleList: contentBlockers) { list, error in
                    if let error {
                        print("🚫 Error compiling content blockers:", error)
                    } else if let list {
                         self.configuration.userContentController.add(list)
                    }
                }
            }
        } catch {
            print("🚫 Error loading content blockers:", error)
        }

        // Configure shared preferences
    let preferences = WKPreferences()
    preferences.isElementFullscreenEnabled = true
    configuration.preferences = preferences

        let webPagePreferences = WKWebpagePreferences()
        webPagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = webPagePreferences

        installUserScripts()
    }

    /// Installs the JavaScript listeners once for every web view.
    /// Messages are routed to the controller that owns the web view that sent them.
    private func installUserScripts() {
        let controller = configuration.userContentController
        for (resource, messageName) in [("HoverURLListener", "hoverURL"), ("MiddleClickLinkListener", "middleClickLink")] {
            guard let scriptURL = Bundle.main.url(forResource: resource, withExtension: "js"),
                  let source = try? String(contentsOf: scriptURL, encoding: .utf8) else { continue }
            controller.add(WebViewScriptMessageRouter.shared, name: messageName)
            controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
    }
}

/// Single script message handler shared by all web views.
/// `WKUserContentController` retains its handlers, so registering each tab's controller
/// would leak it and send every tab's messages to the last registered tab.
final class WebViewScriptMessageRouter: NSObject, WKScriptMessageHandler {
    static let shared = WebViewScriptMessageRouter()

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let webView = message.webView as? MyWKWebView else { return }
        webView.scriptMessageHandler?.handleScriptMessage(message)
    }
}
