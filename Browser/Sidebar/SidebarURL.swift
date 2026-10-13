//
//  SidebarURL.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/20/25.
//

import SwiftUI

struct SidebarURL: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(BrowserWindowState.self) var browserWindowState
    @EnvironmentObject var userPreferences: UserPreferences
    
    @State var hover = false
    @State var showSiteSettings = false
    
    var body: some View {
        HStack {
            if let currentTab = browserWindowState.currentSpace?.currentTab {
                Text(currentTab.url.cleanHost)
                    .padding(.leading, 8)

                Spacer()
                
                if hover || showSiteSettings {
                    if let host = currentTab.url.host(), !host.isEmpty {
                        Button("Site Settings", systemImage: "slider.horizontal.3") {
                            showSiteSettings.toggle()
                        }
                        .buttonStyle(.sidebarHover(hoverStyle: AnyShapeStyle(.ultraThinMaterial) ,cornerRadius: 7))
                        .popover(isPresented: $showSiteSettings, arrowEdge: .bottom) {
                            SiteSettingsPopover(host: host)
                        }
                        .browserTransition(.opacity)
                    }
                    
                    Button("Copy URL To Clipboard", systemImage: "link", action: browserWindowState.copyURLToClipboard)
                        .buttonStyle(.sidebarHover(hoverStyle: AnyShapeStyle(.ultraThinMaterial) ,cornerRadius: 7))
                        .padding(.trailing, .sidebarPadding)
                        .browserTransition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .contentShape(Rectangle())
        .background(.clear)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .overlay(alignment: .bottom) {
            if userPreferences.loadingIndicatorPosition == .onURL && browserWindowState.currentSpace?.currentTab?.isLoading == true {
                ProgressView(value: browserWindowState.currentSpace?.currentTab?.estimatedProgress ?? 0)
                    .progressViewStyle(.linear)
                    .frame(height: 2)
                    .tint(browserWindowState.currentSpace?.getColors.first ?? .accentColor)
            }
        }
        .clipShape(.rect(cornerRadius: 10))
        .onTapGesture {
            browserWindowState.searchOpenLocation = .fromURLBar
        }
        .onHover { hover in
            withAnimation(.browserDefault?.speed(2)) {
                self.hover = hover
            }
        }
        .zIndex(-1)
    }
}

#Preview {
    SidebarURL()
}
