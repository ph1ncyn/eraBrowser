//
//  SidebarExtensionButtons.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import SwiftUI
import WebKit

/// Toolbar buttons of the installed web extensions, plus "Add to era" on Chrome Web Store / Firefox Add-ons pages
struct SidebarExtensionButtons: View {
    @Environment(BrowserWindowState.self) var browserWindowState
    var manager = WebExtensionsManager.shared

    @State var isInstalling = false

    /// Extensions shown as buttons; the others go in the overflow menu
    private let maxVisibleButtons = 3

    var currentURL: URL? {
        browserWindowState.currentSpace?.currentTab?.url
    }

    var body: some View {
        // Read so the buttons refresh when an extension updates its icon or badge
        let _ = manager.actionsVersion
        let contexts = manager.loadedContexts

        HStack(spacing: 2) {
            if let currentURL, WebExtensionSource(currentURL.absoluteString) != nil {
                Button("Add to era", systemImage: isInstalling ? "hourglass" : "plus.app") {
                    installFromCurrentPage(currentURL)
                }
                .disabled(isInstalling)
                .help("Install this extension in era")
                .buttonStyle(.sidebarHover())
            }

            ForEach(contexts.prefix(maxVisibleButtons), id: \.uniqueIdentifier) { context in
                ExtensionActionButton(context: context)
            }

            if contexts.count > maxVisibleButtons {
                Menu {
                    ForEach(contexts.dropFirst(maxVisibleButtons), id: \.uniqueIdentifier) { context in
                        Button(context.webExtension.displayName ?? "Extension") {
                            manager.performAction(for: context, in: browserWindowState)
                        }
                    }
                } label: {
                    Image(systemName: "puzzlepiece.extension")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
    }

    private func installFromCurrentPage(_ url: URL) {
        isInstalling = true
        Task { @MainActor in
            do {
                try await manager.install(fromStore: url.absoluteString)
            } catch {
                NSAlert(error: error).runModal()
            }
            isInstalling = false
        }
    }
}

/// The toolbar button of one extension: icon + badge, click runs its action (usually a popup)
struct ExtensionActionButton: View {
    @Environment(BrowserWindowState.self) var browserWindowState
    let context: WKWebExtensionContext
    var manager = WebExtensionsManager.shared

    var body: some View {
        let _ = manager.actionsVersion
        let action = manager.action(for: context, in: browserWindowState)
        let icon = action?.icon(for: CGSize(width: 16, height: 16))
            ?? context.webExtension.icon(for: CGSize(width: 16, height: 16))

        Button {
            manager.performAction(for: context, in: browserWindowState)
        } label: {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "puzzlepiece.extension")
                }
            }
            .frame(width: 16, height: 16)
            .overlay(alignment: .topTrailing) {
                if let badge = action?.badgeText, !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 2)
                        .background(.red, in: .capsule)
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.sidebarHover())
        .disabled(action?.isEnabled == false)
        .help(action?.label ?? context.webExtension.displayName ?? "Extension")
        .contextMenu {
            if context.optionsPageURL != nil {
                Button("Extension Settings…") {
                    manager.openOptionsPage(for: context)
                }
            }
        }
    }
}
