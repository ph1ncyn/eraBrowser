//
//  PageToolbar.swift
//  Browser
//
//  Created by ph1ncyn on 10/14/26.
//

import SwiftUI

/// Toolbar above the page (Settings → Appearance → Address Bar → Above the Page):
/// back, forward, the address bar, the extensions and eraAI
struct PageToolbar: View {
    @Environment(BrowserWindowState.self) var browserWindowState

    var currentTab: BrowserTab? {
        browserWindowState.currentSpace?.currentTab
    }

    var body: some View {
        HStack(spacing: 6) {
            SidebarToolbarButton("chevron.left", disabled: currentTab?.canGoBack != true, action: browserWindowState.backButtonAction)
                .help("Back (⌘[)")
            SidebarToolbarButton("chevron.right", disabled: currentTab?.canGoForward != true, action: browserWindowState.forwardButtonAction)
                .help("Forward (⌘])")

            Spacer(minLength: 8)

            SidebarURL()
                .frame(maxWidth: 640)

            Spacer(minLength: 8)

            SidebarExtensionButtons()

            SidebarToolbarButton("sparkles", action: browserWindowState.toggleEraAI)
                .help("Ask eraAI about this page (⌘⇧E)")
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
    }
}
