//
//  WebExtensionsManager.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import SwiftUI
import WebKit

/// An installed web extension, persisted in `UserDefaults`
struct InstalledWebExtension: Codable, Identifiable, Equatable {
    /// Unique identifier (`browser.runtime.id`), also the host of the extension's base URL
    let id: String
    /// Package (ZIP) or folder name inside the extensions directory
    let fileName: String
    var isEnabled: Bool = true
    var sourceDescription: String?
    var installedAt: Date = .now
}

/// Loads web extensions (Chrome / Firefox / Safari WebExtensions) with WebKit's `WKWebExtensionController`
/// and connects them to era's windows and tabs.
@Observable
final class WebExtensionsManager: NSObject {
    static let shared = WebExtensionsManager()

    /// Attached to every (non No-Trace) web view configuration
    @ObservationIgnored let controller = WKWebExtensionController()

    private(set) var installed: [InstalledWebExtension] = []
    /// Loaded contexts by extension id
    private(set) var contexts: [String: WKWebExtensionContext] = [:]
    /// Load errors by extension id
    private(set) var loadErrors: [String: String] = [:]
    /// Incremented when an extension action (icon, badge…) changes, to refresh the toolbar
    private(set) var actionsVersion = 0

    @ObservationIgnored private var tabAdapters: [UUID: ExtensionTab] = [:]
    @ObservationIgnored private var openedTabIDs: Set<UUID> = []
    @ObservationIgnored private var windowAdapters: [ObjectIdentifier: ExtensionWindow] = [:]

    private static let userDefaultsKey = "web_extensions"

    /// Application Support/Extensions (inside the app container)
    let extensionsDirectory: URL = {
        let directory = URL.applicationSupportDirectory.appending(path: "Extensions", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    private override init() {
        super.init()
        controller.delegate = self
        if let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
           let installed = try? JSONDecoder().decode([InstalledWebExtension].self, from: data) {
            self.installed = installed
        }
        Task { @MainActor in
            for item in self.installed where item.isEnabled {
                await self.load(item)
            }
        }
    }

    private func saveInstalled() {
        if let data = try? JSONEncoder().encode(installed) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }

    func context(for item: InstalledWebExtension) -> WKWebExtensionContext? {
        contexts[item.id]
    }

    /// Loaded extensions that have a toolbar action, in install order
    var loadedContexts: [WKWebExtensionContext] {
        installed.compactMap { contexts[$0.id] }
    }

    // MARK: - Loading

    @MainActor
    private func load(_ item: InstalledWebExtension) async {
        let url = extensionsDirectory.appending(path: item.fileName)
        do {
            let webExtension = try await WKWebExtension(resourceBaseURL: url)
            let context = WKWebExtensionContext(for: webExtension)
            context.uniqueIdentifier = item.id
            if let baseURL = URL(string: "webkit-extension://\(item.id)/") {
                context.baseURL = baseURL
            }
            context.isInspectable = true

            // The user approved these permissions when installing the extension
            for permission in webExtension.requestedPermissions {
                context.setPermissionStatus(.grantedExplicitly, for: permission)
            }
            for matchPattern in webExtension.allRequestedMatchPatterns {
                context.setPermissionStatus(.grantedExplicitly, for: matchPattern)
            }

            try controller.load(context)
            contexts[item.id] = context
            loadErrors[item.id] = nil
        } catch {
            print("🧩 Error loading extension \(item.fileName): \(error)")
            loadErrors[item.id] = error.localizedDescription
        }
    }

    private func unload(_ item: InstalledWebExtension) {
        guard let context = contexts[item.id] else { return }
        try? controller.unload(context)
        contexts[item.id] = nil
    }

    // MARK: - Installing

    /// Installs from a Chrome Web Store / Firefox Add-ons link or a Chrome extension ID
    @MainActor
    func install(fromStore input: String) async throws {
        guard let source = WebExtensionSource(input) else {
            throw WebExtensionInstallError.unsupportedInput
        }
        let data = try await WebExtensionPackage.download(source)
        try await installPackage(data, preferredIdentifier: source.preferredIdentifier, sourceDescription: source.storeName)
    }

    /// Installs a `.crx`, `.xpi` or `.zip` file, or an unpacked extension folder (with a manifest.json)
    @MainActor
    func install(fromFile url: URL) async throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path(), isDirectory: &isDirectory)

        if isDirectory.boolValue {
            let id = Self.newIdentifier()
            let fileName = id
            let destination = extensionsDirectory.appending(path: fileName, directoryHint: .isDirectory)
            try FileManager.default.copyItem(at: url, to: destination)
            try await finishInstall(id: id, fileName: fileName, sourceDescription: "Folder: \(url.lastPathComponent)")
        } else {
            let data = try Data(contentsOf: url)
            try await installPackage(data, preferredIdentifier: nil, sourceDescription: "File: \(url.lastPathComponent)")
        }
    }

    @MainActor
    private func installPackage(_ data: Data, preferredIdentifier: String?, sourceDescription: String) async throws {
        let zip = try WebExtensionPackage.zipData(from: data)
        var id = preferredIdentifier ?? Self.newIdentifier()

        // Reinstalling (updating) an extension from the store keeps its data
        if let existing = installed.first(where: { $0.id == id }) {
            uninstall(existing, removeData: false)
        } else if installed.contains(where: { $0.id == id }) {
            id = Self.newIdentifier()
        }

        let fileName = "\(id).zip"
        try zip.write(to: extensionsDirectory.appending(path: fileName))
        try await finishInstall(id: id, fileName: fileName, sourceDescription: sourceDescription)
    }

    /// Validates the package, asks the user to approve its permissions, then loads it
    @MainActor
    private func finishInstall(id: String, fileName: String, sourceDescription: String) async throws {
        let url = extensionsDirectory.appending(path: fileName)
        do {
            let webExtension = try await WKWebExtension(resourceBaseURL: url)
            guard Self.confirmInstall(webExtension) else {
                try? FileManager.default.removeItem(at: url)
                return
            }
            let item = InstalledWebExtension(id: id, fileName: fileName, sourceDescription: sourceDescription)
            installed.append(item)
            saveInstalled()
            await load(item)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    private static func newIdentifier() -> String {
        UUID().uuidString.lowercased()
    }

    @MainActor
    private static func confirmInstall(_ webExtension: WKWebExtension) -> Bool {
        let name = webExtension.displayName ?? "This extension"
        let permissions = webExtension.requestedPermissions.map(\.rawValue).sorted()
        let hosts = webExtension.allRequestedMatchPatterns.map(\.string).sorted()

        var details: [String] = []
        if let description = webExtension.displayDescription, !description.isEmpty {
            details.append(description)
        }
        if !permissions.isEmpty {
            details.append("Permissions: " + permissions.joined(separator: ", "))
        }
        if !hosts.isEmpty {
            let shownHosts = hosts.prefix(8).joined(separator: ", ") + (hosts.count > 8 ? "…" : "")
            details.append("Can read and change data on: " + shownHosts)
        }

        let alert = NSAlert()
        alert.messageText = "Add \"\(name)\" to era?"
        alert.informativeText = details.joined(separator: "\n\n")
        if let icon = webExtension.icon(for: CGSize(width: 64, height: 64)) {
            alert.icon = icon
        }
        alert.addButton(withTitle: "Add Extension")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Managing

    @MainActor
    func setEnabled(_ enabled: Bool, for item: InstalledWebExtension) {
        guard let index = installed.firstIndex(where: { $0.id == item.id }) else { return }
        installed[index].isEnabled = enabled
        saveInstalled()
        if enabled {
            Task { @MainActor in await load(installed[index]) }
        } else {
            unload(item)
        }
    }

    /// Removes the extension, and its storage unless `removeData` is false (used when updating)
    func uninstall(_ item: InstalledWebExtension, removeData: Bool = true) {
        if removeData, let context = contexts[item.id] {
            let dataTypes = WKWebExtensionController.allExtensionDataTypes
            controller.fetchDataRecord(ofTypes: dataTypes, for: context) { [controller] record in
                if let record {
                    controller.removeData(ofTypes: dataTypes, from: [record]) {}
                }
            }
        }
        unload(item)
        try? FileManager.default.removeItem(at: extensionsDirectory.appending(path: item.fileName))
        installed.removeAll { $0.id == item.id }
        loadErrors[item.id] = nil
        saveInstalled()
    }

    /// Opens the extension's options page
    func openOptionsPage(for context: WKWebExtensionContext) {
        guard let url = context.optionsPageURL else { return }
        ExtensionPageWindow.show(url: url, context: context)
    }

    /// Runs the extension's toolbar action (popup or `action.onClicked`) for the current tab of a window
    func performAction(for context: WKWebExtensionContext, in windowState: BrowserWindowState) {
        let tab = windowState.currentSpace?.currentTab.map { extensionTab(for: $0, in: windowState) }
        context.performAction(for: tab)
    }

    func action(for context: WKWebExtensionContext, in windowState: BrowserWindowState) -> WKWebExtension.Action? {
        let tab = windowState.currentSpace?.currentTab.map { extensionTab(for: $0, in: windowState) }
        return context.action(for: tab)
    }

    // MARK: - Windows and tabs

    func extensionWindow(for windowState: BrowserWindowState) -> ExtensionWindow {
        let key = ObjectIdentifier(windowState)
        if let window = windowAdapters[key] {
            return window
        }
        let window = ExtensionWindow(windowState: windowState)
        windowAdapters[key] = window
        return window
    }

    func extensionTab(for tab: BrowserTab, in windowState: BrowserWindowState?) -> ExtensionTab {
        if let adapter = tabAdapters[tab.id] {
            if let windowState {
                adapter.browserWindowState = windowState
            }
            return adapter
        }
        let adapter = ExtensionTab(tab: tab, windowState: windowState)
        tabAdapters[tab.id] = adapter
        return adapter
    }

    /// Browser windows that extensions can see (No-Trace windows don't run extensions)
    private var openWindows: [ExtensionWindow] {
        windowAdapters = windowAdapters.filter { $0.value.browserWindowState != nil }
        return windowAdapters.values.filter { $0.browserWindowState?.isNoTraceWindow == false }
    }

    private var focusedWindow: ExtensionWindow? {
        openWindows.first { $0.browserWindowState?.nsWindow?.isKeyWindow == true } ?? openWindows.first
    }

    func windowDidOpen(_ windowState: BrowserWindowState) {
        guard !windowState.isNoTraceWindow else { return }
        controller.didOpenWindow(extensionWindow(for: windowState))
    }

    func windowDidFocus(_ windowState: BrowserWindowState) {
        guard !windowState.isNoTraceWindow else { return }
        controller.didFocusWindow(extensionWindow(for: windowState))
    }

    func windowDidClose(_ windowState: BrowserWindowState) {
        let key = ObjectIdentifier(windowState)
        guard let window = windowAdapters[key] else { return }
        controller.didCloseWindow(window)
        windowAdapters[key] = nil
    }

    func tabDidOpen(_ tab: BrowserTab, in windowState: BrowserWindowState) {
        guard !windowState.isNoTraceWindow, tab.type == .web, !openedTabIDs.contains(tab.id) else { return }
        openedTabIDs.insert(tab.id)
        controller.didOpenTab(extensionTab(for: tab, in: windowState))
    }

    func tabDidClose(_ tab: BrowserTab) {
        openedTabIDs.remove(tab.id)
        guard let adapter = tabAdapters[tab.id] else { return }
        controller.didCloseTab(adapter, windowIsClosing: false)
        tabAdapters[tab.id] = nil
    }

    func tabDidActivate(_ tab: BrowserTab?, previous: BrowserTab?, in windowState: BrowserWindowState) {
        guard !windowState.isNoTraceWindow, let tab, tab.type == .web else { return }
        let previousAdapter = previous.flatMap { tabAdapters[$0.id] }
        controller.didActivateTab(extensionTab(for: tab, in: windowState), previousActiveTab: previousAdapter)
        actionsVersion += 1
    }

    func tabDidChange(_ tab: BrowserTab, properties: WKWebExtension.TabChangedProperties) {
        guard let adapter = tabAdapters[tab.id] else { return }
        controller.didChangeTabProperties(properties, for: adapter)
    }
}

// MARK: - WKWebExtensionControllerDelegate
extension WebExtensionsManager: WKWebExtensionControllerDelegate {

    func webExtensionController(_ controller: WKWebExtensionController, openWindowsFor extensionContext: WKWebExtensionContext) -> [any WKWebExtensionWindow] {
        openWindows
    }

    func webExtensionController(_ controller: WKWebExtensionController, focusedWindowFor extensionContext: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        focusedWindow
    }

    func webExtensionController(_ controller: WKWebExtensionController, openNewTabUsing configuration: WKWebExtension.TabConfiguration, for extensionContext: WKWebExtensionContext, completionHandler: @escaping ((any WKWebExtensionTab)?, (any Error)?) -> Void) {
        let window = (configuration.window as? ExtensionWindow) ?? focusedWindow
        guard let windowState = window?.browserWindowState,
              let space = windowState.currentSpace,
              let modelContext = space.modelContext
        else {
            completionHandler(nil, nil)
            return
        }

        let url = configuration.url ?? URL(string: "about:blank")!
        let order = min(max(configuration.index, 0), space.tabs.count)
        let tab = BrowserTab(title: url.cleanHost, url: url, order: order, browserSpace: space)
        space.openNewTab(tab, using: modelContext, select: configuration.shouldBeActive)
        if configuration.shouldBePinned {
            space.pinTab(tab, using: modelContext)
        }
        completionHandler(extensionTab(for: tab, in: windowState), nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, openNewWindowUsing configuration: WKWebExtension.WindowConfiguration, for extensionContext: WKWebExtensionContext, completionHandler: @escaping ((any WKWebExtensionWindow)?, (any Error)?) -> Void) {
        // era opens the requested tabs in the focused window instead of a new one
        guard let window = focusedWindow,
              let windowState = window.browserWindowState,
              let space = windowState.currentSpace,
              let modelContext = space.modelContext
        else {
            completionHandler(nil, nil)
            return
        }
        for url in configuration.tabURLs {
            let tab = BrowserTab(title: url.cleanHost, url: url, order: space.tabs.count, browserSpace: space)
            space.openNewTab(tab, using: modelContext, select: true)
        }
        completionHandler(window, nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, openOptionsPageFor extensionContext: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        openOptionsPage(for: extensionContext)
        completionHandler(nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, presentActionPopup action: WKWebExtension.Action, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        guard let popover = action.popupPopover,
              let window = focusedWindow?.browserWindowState?.nsWindow ?? NSApp.keyWindow,
              let contentView = window.contentView
        else {
            completionHandler(nil)
            return
        }
        // Show the popup under the mouse (the extension button that was just clicked)
        let point = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let anchor = NSRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
        popover.show(relativeTo: anchor, of: contentView, preferredEdge: .maxY)
        completionHandler(nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, didUpdate action: WKWebExtension.Action, forExtensionContext context: WKWebExtensionContext) {
        actionsVersion += 1
    }

    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissions permissions: Set<WKWebExtension.Permission>, in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Set<WKWebExtension.Permission>, Date?) -> Void) {
        let granted = Self.askForPermission(extensionContext, items: permissions.map(\.rawValue))
        completionHandler(granted ? permissions : [], nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>, in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Set<WKWebExtension.MatchPattern>, Date?) -> Void) {
        let granted = Self.askForPermission(extensionContext, items: matchPatterns.map(\.string))
        completionHandler(granted ? matchPatterns : [], nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionToAccess urls: Set<URL>, in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Set<URL>, Date?) -> Void) {
        let granted = Self.askForPermission(extensionContext, items: urls.compactMap { $0.host() })
        completionHandler(granted ? urls : [], nil)
    }

    private static func askForPermission(_ context: WKWebExtensionContext, items: [String]) -> Bool {
        let alert = NSAlert()
        alert.messageText = "\"\(context.webExtension.displayName ?? "An extension")\" requests additional access"
        alert.informativeText = items.sorted().joined(separator: "\n")
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Don't Allow")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
