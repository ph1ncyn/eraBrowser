//
//  WebExtensionAdapters.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import SwiftUI
import WebKit

/// Exposes a browser window to web extensions (`browser.windows`, `browser.tabs.query`…)
final class ExtensionWindow: NSObject, WKWebExtensionWindow {
    weak var browserWindowState: BrowserWindowState?

    init(windowState: BrowserWindowState) {
        self.browserWindowState = windowState
    }

    private var manager: WebExtensionsManager { .shared }

    func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab] {
        guard let windowState = browserWindowState, let space = windowState.currentSpace else { return [] }
        return space.allTabs
            .filter { $0.type == .web }
            .map { manager.extensionTab(for: $0, in: windowState) }
    }

    func activeTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)? {
        guard let windowState = browserWindowState, let tab = windowState.currentSpace?.currentTab, tab.type == .web else { return nil }
        return manager.extensionTab(for: tab, in: windowState)
    }

    func windowType(for context: WKWebExtensionContext) -> WKWebExtension.WindowType {
        .normal
    }

    func windowState(for context: WKWebExtensionContext) -> WKWebExtension.WindowState {
        guard let window = browserWindowState?.nsWindow else { return .normal }
        if window.styleMask.contains(.fullScreen) { return .fullscreen }
        if window.isMiniaturized { return .minimized }
        if window.isZoomed { return .maximized }
        return .normal
    }

    func isPrivate(for context: WKWebExtensionContext) -> Bool {
        browserWindowState?.isNoTraceWindow ?? false
    }

    func frame(for context: WKWebExtensionContext) -> CGRect {
        browserWindowState?.nsWindow?.frame ?? .null
    }

    func screenFrame(for context: WKWebExtensionContext) -> CGRect {
        browserWindowState?.nsWindow?.screen?.frame ?? .null
    }

    func focus(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        browserWindowState?.nsWindow?.makeKeyAndOrderFront(nil)
        completionHandler(nil)
    }

    func close(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        browserWindowState?.nsWindow?.performClose(nil)
        completionHandler(nil)
    }
}

/// Exposes a browser tab to web extensions (`browser.tabs`)
final class ExtensionTab: NSObject, WKWebExtensionTab {
    weak var tab: BrowserTab?
    weak var browserWindowState: BrowserWindowState?

    init(tab: BrowserTab, windowState: BrowserWindowState?) {
        self.tab = tab
        self.browserWindowState = windowState
    }

    private var manager: WebExtensionsManager { .shared }

    private var space: BrowserSpace? {
        guard let tab else { return nil }
        if let space = browserWindowState?.currentSpace, space.allTabs.contains(tab) {
            return space
        }
        return tab.browserSpace
    }

    func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        guard let browserWindowState else { return nil }
        return manager.extensionWindow(for: browserWindowState)
    }

    func indexInWindow(for context: WKWebExtensionContext) -> Int {
        guard let tab, let space else { return NSNotFound }
        return space.allTabs.firstIndex(of: tab) ?? NSNotFound
    }

    func title(for context: WKWebExtensionContext) -> String? {
        tab?.title
    }

    func url(for context: WKWebExtensionContext) -> URL? {
        tab?.webview?.url ?? tab?.url
    }

    func webView(for context: WKWebExtensionContext) -> WKWebView? {
        tab?.webview
    }

    func isPinned(for context: WKWebExtensionContext) -> Bool {
        guard let tab, let space else { return false }
        return space.pinnedTabs.contains(tab)
    }

    func isSelected(for context: WKWebExtensionContext) -> Bool {
        guard let tab, let space else { return false }
        if let browserWindowState {
            return browserWindowState.visibleTabs(in: space).contains(tab)
        }
        return space.currentTab == tab
    }

    func isLoadingComplete(for context: WKWebExtensionContext) -> Bool {
        !(tab?.isLoading ?? false)
    }

    func shouldGrantPermissionsOnUserGesture(for context: WKWebExtensionContext) -> Bool {
        // Lets "activeTab" extensions work on the page the user interacts with
        true
    }

    func loadURL(_ url: URL, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        guard let tab else { return completionHandler(nil) }
        tab.url = url
        tab.webview?.load(URLRequest(url: url))
        completionHandler(nil)
    }

    func reload(fromOrigin: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        if fromOrigin {
            tab?.webview?.reloadFromOrigin()
        } else {
            tab?.reload()
        }
        completionHandler(nil)
    }

    func goBack(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        tab?.webview?.goBack()
        completionHandler(nil)
    }

    func goForward(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        tab?.webview?.goForward()
        completionHandler(nil)
    }

    func activate(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        if let tab, let space {
            space.currentTab = tab
        }
        completionHandler(nil)
    }

    func close(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        if let tab, let space, let modelContext = tab.modelContext {
            space.closeTab(tab, using: modelContext)
        }
        completionHandler(nil)
    }

    func setPinned(_ pinned: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        if let tab, let space, let modelContext = tab.modelContext, space.pinnedTabs.contains(tab) != pinned {
            if pinned {
                space.pinTab(tab, using: modelContext)
            } else {
                space.unpinTab(tab, using: modelContext)
            }
        }
        completionHandler(nil)
    }
}
