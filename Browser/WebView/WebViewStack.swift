//
//  WebView.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/23/25.
//

import SwiftUI

/// View that contains a stack for the loaded tabs in the current space
struct WebViewStack: View {
    @Bindable var browserSpace: BrowserSpace
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext
    @Environment(BrowserWindowState.self) var browserWindowState
    @EnvironmentObject var userPreferences: UserPreferences

    var body: some View {
        ZStack {
            if let currentTab = browserSpace.currentTab {
                ForEach(browserSpace.allTabs.filter { browserSpace.loadedTabs.contains($0) || $0 == currentTab }) { tab in
                    WebView(tab: tab, browserSpace: browserSpace)
                    .zIndex(tab == currentTab ? 1 : 0)
                    .opacity(tab == currentTab ? 1 : 0)
                    .scaleEffect(tab == currentTab ? 1 : 0.95)
                    .animation(.bouncy(duration: 0.3), value: browserSpace.currentTab)
                    .onAppear {
                        if !browserSpace.loadedTabs.contains(tab) {
                            browserSpace.loadedTabs.append(tab)
                        }
                    }
                }
            } else {
                emptyState
            }
        }
        .transaction { $0.animation = .bouncy(duration: 0.3) }
        .onAppear(perform: restoreLastSelectedTab)
        .onChange(of: browserSpace.currentTab) { _, newValue in
            browserSpace.lastSelectedTabID = newValue?.id
        }
    }

    /// Selects the tab that was selected when the browser was closed
    private func restoreLastSelectedTab() {
        guard browserSpace.currentTab == nil,
              userPreferences.restoreSession,
              let lastSelectedTabID = browserSpace.lastSelectedTabID,
              let tab = browserSpace.allTabs.first(where: { $0.id == lastSelectedTabID && !$0.isSuspended })
        else { return }
        browserSpace.currentTab = tab
    }

    /// Shown when the space has no selected tab (e.g. after closing the last one): the window stays open
    private var emptyState: some View {
        VStack(spacing: 16) {
            // Invert the logo in light mode so it remains visible against a light background
            Image("logo")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .opacity(0.3)
                .modifier(InvertInLightMode(colorScheme: colorScheme))

            HStack(spacing: 10) {
                Button("New Tab", systemImage: "plus") {
                    browserWindowState.toggleNewTabSearch()
                }
                .disabled(!browserWindowState.spaceCanOpenNewTab())

                if !browserSpace.recentlyClosedTabs.isEmpty {
                    Button("Reopen Closed Tab", systemImage: "arrow.uturn.backward") {
                        browserSpace.reopenLastClosedTab(using: modelContext)
                    }
                }
            }
            .buttonStyle(.bordered)
            .opacity(0.8)
        }
    }
}

private struct InvertInLightMode: ViewModifier {
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        if colorScheme == .light {
            content.colorInvert()
        } else {
            content
        }
    }
}
