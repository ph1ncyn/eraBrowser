//
//  SettingsAppearanceView.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/7/25.
//

import SwiftUI

struct SettingsAppearanceView: View {
    @EnvironmentObject var userPreferences: UserPreferences
    var body: some View {
        Form {
            Section("Layout") {
                LayoutOptionPicker(
                    title: "Address Bar",
                    systemImage: "link",
                    footer: "\"Above the Page\" keeps back, forward and the address in reach when the sidebar is hidden (⌘S).",
                    selection: $userPreferences.addressBarPosition,
                    options: [
                        LayoutOption(value: .sidebarTop, title: "Sidebar Top"),
                        LayoutOption(value: .sidebarBottom, title: "Sidebar Bottom"),
                        LayoutOption(value: .abovePage, title: "Above the Page")
                    ]
                ) { position in
                    BrowserLayoutMockup(addressBar: position, background: userPreferences.windowBackgroundStyle, emphasis: .addressBar)
                }
                
                LayoutOptionPicker(
                    title: "Loading Indicator",
                    systemImage: "progress.indicator",
                    selection: $userPreferences.loadingIndicatorPosition,
                    options: [
                        LayoutOption(value: .onURL, title: "Address Bar"),
                        LayoutOption(value: .onTab, title: "Tab"),
                        LayoutOption(value: .onWebView, title: "Top of the Page")
                    ]
                ) { position in
                    BrowserLayoutMockup(addressBar: userPreferences.addressBarPosition, loadingIndicator: position, background: userPreferences.windowBackgroundStyle)
                }
            }
            
            Section("Window") {
                LayoutOptionPicker(
                    title: "Background",
                    systemImage: "square.on.square.squareshape.controlhandles",
                    selection: $userPreferences.windowBackgroundStyle,
                    options: [
                        LayoutOption(value: .thinMaterial, title: "Material"),
                        LayoutOption(value: .liquidGlass, title: "Liquid Glass")
                    ]
                ) { style in
                    BrowserLayoutMockup(addressBar: userPreferences.addressBarPosition, background: style)
                }
                
                Toggle("Rounded Page Corners", systemImage: "button.roundedtop.horizontal", isOn: $userPreferences.roundedCorners)
                Toggle("Disable Animations", systemImage: "figure.run", isOn: $userPreferences.disableAnimations)
            }
        }
        .formStyle(.grouped)
    }
}
