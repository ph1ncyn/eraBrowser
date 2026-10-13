//
//  SidebarTabNewButton.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/31/25.
//

import SwiftUI

/// Button to open the search bar for a new tab
struct SidebarTabNewButton: View {
    
    @Environment(\.modelContext) var modelContext
    
    @Environment(BrowserWindowState.self) var browserWindowState
    
    @Bindable var browserSpace: BrowserSpace
    @State var isHovering = false
    
    var body: some View {
        Button(action: openNewTabSearch) {
            HStack {
                Label("New Tab", systemImage: "plus")
                Spacer()
                if isHovering {
                    Text("⌘T")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 8)
                }
            }
                .padding(.leading, .sidebarPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 30)
                .padding(3)
                .background(isHovering ? .white.opacity(0.1) : .clear)
                .clipShape(.rect(cornerRadius: 10))
                .padding(.leading, .sidebarPadding)
        }
        .buttonStyle(.plain)
        .onHover { isHover in
            self.isHovering = isHover
        }
    }
    
    func openNewTabSearch() {
        browserWindowState.searchOpenLocation = .fromNewTab
    }
}
