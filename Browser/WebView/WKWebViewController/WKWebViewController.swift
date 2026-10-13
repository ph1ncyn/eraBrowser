//
//  WKWebViewController.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/2/25.
//

import SwiftUI
import WebKit
import SwiftData

/// Main view controller that contains a WKWebView
class WKWebViewController: NSViewController {

    @Bindable var tab: BrowserTab
    @Bindable var browserSpace: BrowserSpace
    var userPreferences: UserPreferences

    var webView: MyWKWebView
    let configuration: WKWebViewConfiguration

    weak var coordinator: WKWebViewControllerRepresentable.Coordinator!

    var activeDownloads: [(download: WKDownload, bookmarkData: Data, fileName: String)] = []

    private var suspendTimer: DispatchSourceTimer?

    init(tab: BrowserTab, browserSpace: BrowserSpace, noTrace: Bool = false, using modelContext: ModelContext, userPreferences: UserPreferences) {
        self.tab = tab
        self.browserSpace = browserSpace
        self.userPreferences = userPreferences

        // Never mutate the shared configuration: No-Trace tabs get their own copy with a non-persistent store
        self.configuration = noTrace
            ? SharedWebViewConfiguration.shared.noTraceConfiguration
            : SharedWebViewConfiguration.shared.configuration

        self.webView = MyWKWebView(frame: .zero, configuration: self.configuration)

        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        view = webView

        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15 era/1.0"
        webView.allowsMagnification = true
    webView.allowsLinkPreview = true // TODO: Implement my own preview later...
    webView.isInspectable = true

        // Make webView background transparent
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.clear.cgColor

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scriptMessageHandler = self

        webView.searchWebAction = coordinator.searchWebAction(_:)
        webView.openLinkInNewTabAction = coordinator.openLinkInNewTabAction(_:)
        webView.presentActionAlert = coordinator.presentActionAlert(message:systemImage:)
        webView.askEraAIAction = coordinator.askEraAIAction(_:)

        coordinator.observeWebView(webView)

        // Restore the page (with its back/forward history) if the tab was unloaded or closed before,
        // or from the state saved in the previous session
        if let restorationState = tab.restorationState {
            tab.restorationState = nil
            webView.interactionState = restorationState
        } else if UserDefaults.standard.bool(forKey: "restore_session"), let sessionState = tab.sessionState {
            webView.interactionState = sessionState
        } else {
            webView.load(URLRequest(url: tab.url))
        }

        startSuspendTimer()

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate), name: NSApplication.willTerminateNotification, object: nil)
    }

    /// Saves the page's back/forward state so the session can be restored on the next launch
    @objc private func applicationWillTerminate() {
        tab.saveSessionState()
        try? tab.modelContext?.save()
    }

    deinit {
        print("🔵 WKWebViewController deinit \(tab.title)")
        cleanup()
    }

    func cleanup() {
        // Only deinit if the tab is not loaded or was closed
        if !browserSpace.loadedTabs.contains(tab) {
            tearDown(saveState: false)
        }
    }

    private var isTornDown = false

    /// Stops the page (media, scripts, network) and breaks the reference cycles that kept the
    /// web view alive after its tab was suspended or closed.
    /// - Parameter saveState: Keep the back/forward state on the tab so it can be restored later
    func tearDown(saveState: Bool) {
        guard !isTornDown else { return }
        isTornDown = true

        if saveState {
            tab.restorationState = webView.interactionState
            if let state = webView.interactionState as? Data {
                tab.sessionState = state
            }
        }

        cancelSuspendTimer()
        webView.pauseAllMediaPlayback(completionHandler: nil)
        webView.stopLoading()
        // Blank hidden pages right away so audio, timers and workers stop even if SwiftUI keeps the view a bit longer
        if webView.isHidden || webView.window == nil {
            webView.loadHTMLString("", baseURL: nil)
        }
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.scriptMessageHandler = nil
        webView.searchWebAction = nil
        webView.openLinkInNewTabAction = nil
        webView.presentActionAlert = nil
        webView.askEraAIAction = nil
        coordinator?.stopObservingWebView()
        NotificationCenter.default.removeObserver(self, name: NSApplication.willTerminateNotification, object: nil)

        if tab.webview === webView {
            tab.webview = nil
        }
        if tab.viewController === self {
            tab.viewController = nil
        }
    }

    func startSuspendTimer() {
        guard UserDefaults.standard.bool(forKey: "automatic_page_suspension") else {
            return
        }

        // Don't start timer for pinned tabs
        if browserSpace.pinnedTabs.contains(tab) {
            return
        }

        suspendTimer?.cancel()

        suspendTimer = DispatchSource.makeTimerSource(queue: .main)
        suspendTimer?.schedule(deadline: .now() + 60 * 10) // 10 minutes
        suspendTimer?.setEventHandler { [weak self] in
            guard let self else { return }
            // Don't suspend if the tab is currently active.
            if self.browserSpace.currentTab == self.tab {
                self.resetSuspendTimer()
            } else {
                self.tab.isSuspended = true
                self.browserSpace.unloadTab(self.tab)
            }
        }

        suspendTimer?.resume()
    }

    func resetSuspendTimer() {
        startSuspendTimer()
    }

    func cancelSuspendTimer() {
        suspendTimer?.cancel()
        suspendTimer = nil
    }

    func applyTransparency() {
        guard let url = webView.url else { return }

        let js: String
        // Check if styles are enabled for this specific website
        if StyleManager.shared.areStylesEnabled(for: url),
           let style = StyleManager.shared.getStyle(for: url) {
            // Apply the style
            let escapedCSS = style
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            
            js = """
            (function() {
                var style = document.getElementById('transparency-style');
                if (!style) {
                    style = document.createElement('style');
                    style.id = 'transparency-style';
                    document.head.appendChild(style);
                }
                style.textContent = `\(escapedCSS)`;
            })();
            """
        } else {
            // Remove the style if disabled or not available
            js = """
            (function() {
                var style = document.getElementById('transparency-style');
                if (style) {
                    style.remove();
                }
            })();
            """
        }
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
