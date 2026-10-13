//
//  SidebarURL.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/20/25.
//

import SwiftUI

/// The address bar of the sidebar: site icon + host, opens the Spotlight search to edit the address
struct SidebarURL: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(BrowserWindowState.self) var browserWindowState
    @EnvironmentObject var userPreferences: UserPreferences
    
    @State var hover = false
    @State var showSiteSettings = false
    
    var currentTab: BrowserTab? {
        browserWindowState.currentSpace?.currentTab
    }
    
    var body: some View {
        HStack(spacing: 6) {
            leadingIcon
                .frame(width: 16, height: 16)
            
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(currentTab == nil ? .secondary : .primary)
            
            Spacer(minLength: 2)
            
            if let currentTab {
                if hover || showSiteSettings {
                    siteButtons(for: currentTab)
                        .browserTransition(.opacity)
                }
                
                Button(currentTab.isLoading ? "Stop" : "Reload", systemImage: currentTab.isLoading ? "xmark" : "arrow.clockwise") {
                    if currentTab.isLoading {
                        currentTab.webview?.stopLoading()
                    } else {
                        browserWindowState.refreshButtonAction()
                    }
                }
                .buttonStyle(.sidebarHover(font: .system(size: 13, weight: .medium), fixedWidth: 24, cornerRadius: 7))
                .help(currentTab.isLoading ? "Stop Loading" : "Reload (⌘ click: in a new tab)")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .contentShape(Rectangle())
        .glassEffect(in: .rect(cornerRadius: 13))
        .overlay(alignment: .bottom) {
            if userPreferences.loadingIndicatorPosition == .onURL, let currentTab, currentTab.isLoading {
                ProgressView(value: currentTab.estimatedProgress)
                    .progressViewStyle(.linear)
                    .frame(height: 2)
                    .tint(browserWindowState.currentSpace?.getColors.first ?? .accentColor)
                    .padding(.horizontal, 12)
            }
        }
        .onTapGesture {
            browserWindowState.searchOpenLocation = currentTab == nil ? .fromNewTab : .fromURLBar
        }
        .onHover { hover in
            withAnimation(.browserDefault?.speed(2)) {
                self.hover = hover
            }
        }
        .help(currentTab?.url.absoluteString ?? "Search or enter address (⌘T)")
        .zIndex(-1)
    }
    
    var title: String {
        guard let currentTab else { return "Search or enter address" }
        return currentTab.url.cleanHost.isEmpty ? currentTab.title : currentTab.url.cleanHost
    }
    
    @ViewBuilder
    var leadingIcon: some View {
        if let currentTab {
            if currentTab.url.scheme == "https" {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else if currentTab.url.scheme == "http" {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .help("Not secure")
            } else {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
            }
        } else {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
        }
    }
    
    /// Site settings, website theme and copy link, shown on hover
    @ViewBuilder
    func siteButtons(for tab: BrowserTab) -> some View {
        let style = SidebarHoverButtonStyle.sidebarHover(font: .system(size: 13, weight: .medium), fixedWidth: 24, cornerRadius: 7)
        
        if let host = tab.url.host(), !host.isEmpty {
            Button("Site Settings", systemImage: "slider.horizontal.3") {
                showSiteSettings.toggle()
            }
            .buttonStyle(style)
            .help("Site Settings")
            .popover(isPresented: $showSiteSettings, arrowEdge: .bottom) {
                SiteSettingsPopover(host: host)
            }
            
            let stylesEnabled = StyleManager.shared.areStylesEnabled(for: tab.url)
            Button("Website Theme", systemImage: stylesEnabled ? "paintbrush.fill" : "paintbrush") {
                StyleManager.shared.toggleStyles(for: tab.url)
                tab.viewController?.applyTransparency()
            }
            .buttonStyle(style)
            .help(stylesEnabled ? "Turn Off Website Theme" : "Turn On Website Theme")
        }
        
        Button("Copy Link", systemImage: "link", action: browserWindowState.copyURLToClipboard)
            .buttonStyle(style)
            .help("Copy Link (⌘⇧C)")
    }
}
