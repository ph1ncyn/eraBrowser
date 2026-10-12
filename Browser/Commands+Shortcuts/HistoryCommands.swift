//
//  HistoryCommands.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/16/25.
//

import SwiftUI
import SwiftData
import KeyboardShortcuts

/// Commands for the history menu
struct HistoryCommands: Commands {
    
    @Environment(\.modelContext) var modelContext
    
    @FocusedValue(\.browserActiveWindowState) var browserWindowState: BrowserWindowState?
    
    var body: some Commands {
        CommandMenu("History") {
            if let webView = browserWindowState?.currentSpace?.currentTab?.webview {
                
                Button("Go Back") { webView.goBack() }
                    .disabled(!webView.canGoBack)
                    .globalKeyboardShortcut(.goBack)
                
                Button("Go Forward") { webView.goForward() }
                    .disabled(!webView.canGoForward)
                    .globalKeyboardShortcut(.goForward)
            }
            
            Divider()
            
            let recentlyClosedTabs = browserWindowState?.currentSpace?.recentlyClosedTabs ?? []
            
            Button("Reopen Closed Tab", action: reopenLastClosedTab)
                .disabled(recentlyClosedTabs.isEmpty)
                .globalKeyboardShortcut(.reopenClosedTab)
            
            Menu("Recently Closed") {
                ForEach(recentlyClosedTabs.prefix(15)) { tab in
                    Button(tab.title.isEmpty ? tab.url.absoluteString : tab.title) {
                        reopen(tab)
                    }
                }
            }
            .disabled(recentlyClosedTabs.isEmpty)
            
            Divider()
            
            Button("Show History", action: showHistory)
                .globalKeyboardShortcut(.showHistory)
            
            Button("Clear History") {
                BrowserHistoryEntry.deleteAllHistory(using: modelContext)
            }
            .globalKeyboardShortcut(.clearHistory)
        }
    }
    
    func reopenLastClosedTab() {
        guard let space = browserWindowState?.currentSpace,
              let tab = space.recentlyClosedTabs.first else { return }
        reopen(tab)
    }
    
    func reopen(_ tab: BrowserTab) {
        // Save with the tab's own context; the commands environment may not share the window's container
        browserWindowState?.currentSpace?.reopenTab(tab, using: tab.modelContext ?? modelContext)
    }
    
    func showHistory() {
        let favicon = ImageRenderer(content: Image(systemName: "arrow.counterclockwise.square.fill").resizable().frame(width: 32, height: 32).scaledToFit().foregroundStyle(.gray)).nsImage?.pngData
        let historyTab = BrowserTab(title: "History", favicon: favicon, url: URL(string: "History")!, order: 0, browserSpace: browserWindowState?.currentSpace, type: .history)
        
        do {
            browserWindowState?.currentSpace?.tabs.append(historyTab)
            try modelContext.save()
            browserWindowState?.currentSpace?.currentTab = historyTab
        } catch {
            print("Error saving history tab: \(error)")
        }
    }
}

extension KeyboardShortcuts.Name {
    static let goBack = Self("go_back", default: .init(.leftBracket, modifiers: .command))
    static let goForward = Self("go_forward", default: .init(.rightBracket, modifiers: .command))
    
    static let reopenClosedTab = Self("reopen_closed_tab", default: .init(.t, modifiers: [.command, .shift]))
    
    static let showHistory = Self("show_history", default: .init(.y, modifiers: .command))
    static let clearHistory = Self("clear_history")
}

extension [KeyboardShortcuts.Name] {
    static let allHistoryCommands: [KeyboardShortcuts.Name] = [.goBack, .goForward, .reopenClosedTab, .showHistory, .clearHistory]
}
