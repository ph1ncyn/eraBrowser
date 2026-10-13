//
//  ContentView.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/18/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State var browserWindowState = BrowserWindowState()
    @EnvironmentObject var userPreferences: UserPreferences
    
    @ViewBuilder
    private var mainFrameWithBackground: some View {
        if userPreferences.windowBackgroundStyle == .liquidGlass {
            MainFrame()
                .background(Color.clear.glassEffect(in: .rect(cornerRadius: 10.0)))
        } else {
            MainFrame()
                .background(.thinMaterial)
        }
    }

    var body: some View {
        mainFrameWithBackground
            .ignoresSafeArea(.all)
            .focusedSceneValue(\.browserActiveWindowState, browserWindowState)
            .background(WindowAccessor { window in
                browserWindowState.nsWindow = window
                if window != nil {
                    WebExtensionsManager.shared.windowDidOpen(browserWindowState)
                }
            })
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
                if let window = notification.object as? NSWindow, window === browserWindowState.nsWindow {
                    WebExtensionsManager.shared.windowDidFocus(browserWindowState)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                if let window = notification.object as? NSWindow, window === browserWindowState.nsWindow {
                    WebExtensionsManager.shared.windowDidClose(browserWindowState)
                }
            }
            .environment(browserWindowState)
            .sheet(isPresented: $browserWindowState.showURLQRCode) {
                if let currentTab = browserWindowState.currentSpace?.currentTab {
                    URLQRCodeView(browserTab: currentTab)
                }
            }
            .popover(
                isPresented: $browserWindowState.showAcknowledgements,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .top
            ) {
                Acknowledgments()
                    .environment(browserWindowState)
                    .frame(width: 500, height: 300)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
            }

    }
}
