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
            if browserSpace.currentTab != nil {
                // The current tab, or all the tabs of its split view
                let visibleTabs = browserWindowState.visibleTabs(in: browserSpace)
                let isSplit = visibleTabs.count > 1

                SplitViewLayout(visibleIDs: visibleTabs.map(\.id), style: browserWindowState.splitLayout(in: browserSpace)) {
                    ForEach(browserSpace.allTabs.filter { browserSpace.loadedTabs.contains($0) || visibleTabs.contains($0) }) { tab in
                        let isVisible = visibleTabs.contains(tab)
                        WebView(tab: tab, browserSpace: browserSpace)
                            .clipShape(.rect(cornerRadius: isSplit ? 8 : 0))
                            .overlay {
                                // Highlight the focused pane of a split view
                                if isSplit && tab == browserSpace.currentTab {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(browserSpace.getColors.first ?? .accentColor, lineWidth: 2)
                                        .opacity(0.8)
                                        .allowsHitTesting(false)
                                }
                            }
                            .zIndex(isVisible ? 1 : 0)
                            .opacity(isVisible ? 1 : 0)
                            .scaleEffect(isVisible ? 1 : 0.95)
                            .animation(.bouncy(duration: 0.3), value: browserSpace.currentTab)
                            .onAppear {
                                if !browserSpace.loadedTabs.contains(tab) {
                                    browserSpace.loadedTabs.append(tab)
                                }
                            }
                            .layoutValue(key: SplitTabIDKey.self, value: tab.id)
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
