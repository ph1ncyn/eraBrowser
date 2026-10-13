//
//  Sidebar.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/18/25.
//

import SwiftUI

/// The main sidebar view
struct Sidebar: View {
    
    @Environment(\.modelContext) var modelContext
    
    @Environment(SidebarModel.self) var sidebarModel
    
    @EnvironmentObject var userPreferences: UserPreferences
    @Environment(BrowserWindowState.self) var browserWindowState
    
    let browserSpaces: [BrowserSpace]
    
    var body: some View {
        VStack {
            HStack(spacing: 6){
                SidebarURL()
                SidebarToolbar(browserSpaces: browserSpaces)
            }
            .padding(.top, 12)
            SidebarSpacesTabView(browserSpaces: browserSpaces)
            SidebarBottomToolbar(browserSpaces: browserSpaces, createSpace: createSpace)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(sidebarModel.currentSidebarWidth == 0 ? 0 : 1)
        .gesture(WindowDragGesture()) // Move the browser window by dragging the sidebar
        .task {
            applyLaunchSessionPolicy()
            if browserSpaces.isEmpty {
                createSpace()
            } else if !NSApp.isKeyWindowOfTypeMain && !NSApp.isKeyWindowSettings && browserSpaces.isEmpty {
                createSpace()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            // If the window is not the main browser window, delete the window temporary space
            if !browserWindowState.isMainBrowserWindow {
                guard NSWindow.hasPrefix("Browser", in: notification.object as? NSWindow) else { return }
                do {
                    guard let space = browserWindowState.currentSpace else { return }
                    space.tabs.forEach { modelContext.delete($0) }
                    modelContext.delete(space)
                    try modelContext.save()
                } catch {
                    print("Error deleting temporary spaces: \(error)")
                }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if sidebarModel.showDownloads {
                DownloadsList()
                    .padding(.leading, .sidebarPadding)
                    .padding(.bottom, 44)
            }
        }
    }
    
    /// Closes the previous session's tabs once per launch when "Restore Tabs From Last Session" is off.
    /// Pinned tabs are kept, closed tabs can still be reopened from History.
    private static var didApplyLaunchSessionPolicy = false
    
    private func applyLaunchSessionPolicy() {
        guard !Self.didApplyLaunchSessionPolicy, browserWindowState.isMainBrowserWindow else { return }
        Self.didApplyLaunchSessionPolicy = true
        guard !userPreferences.restoreSession else { return }
        for space in browserSpaces {
            space.closeTabs(space.tabs, using: modelContext)
        }
    }
    
    func createSpace() {
        do {
            let nextIndex = (browserSpaces.firstIndex(where: { $0.id == browserWindowState.currentSpace?.id }) ?? -1) + 1
            
            var newSpace: BrowserSpace
            
            if browserWindowState.isMainBrowserWindow {
                newSpace = BrowserSpace(name: "", systemImage: "circle.fill", order: nextIndex, colors: [], colorScheme: "system")
            } else if browserWindowState.isNoTraceWindow {
                newSpace = BrowserSpace(name: "No-Trace Window", systemImage: "sunglasses.fill", order: 0, colors: [.black], colorScheme: "system")
            } else {
                newSpace = BrowserSpace(name: "Temporary Window", systemImage: "circle.fill", order: 0, colors: [], colorScheme: "system")
            }
            
            modelContext.insert(newSpace)
            try modelContext.save()
            
            // Select the new space
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                browserWindowState.goToSpace(newSpace)
            }
            
            if browserSpaces.count > 1 {
                // Update all spaces order
                for (index, space) in browserSpaces.enumerated() {
                    space.order = index
                }
                try modelContext.save()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
