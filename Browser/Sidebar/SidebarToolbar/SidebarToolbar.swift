//
//  SidebarToolbar.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/23/25.
//

import SwiftUI

/// Buttons next to the address bar: the web extensions (and "Add to era" on store pages)
struct SidebarToolbar: View {
    let browserSpaces: [BrowserSpace]
    
    var body: some View {
        SidebarExtensionButtons()
    }
}
