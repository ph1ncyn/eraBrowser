//
//  SiteSettingsPopover.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import SwiftUI

/// Permission settings for the website of the current tab
struct SiteSettingsPopover: View {
    let host: String
    var store = SitePermissionStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(SitePermissionStore.normalizedHost(host))
                .font(.headline)

            ForEach(SitePermission.allCases) { permission in
                SitePermissionPicker(permission: permission, host: host, store: store)
            }

            Divider()

            Button("Reset Permissions") {
                store.reset(host: host)
            }
            .disabled(store.decisions[SitePermissionStore.normalizedHost(host)] == nil)

            Text("Changes apply to new requests. Reload the page if it already asked.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 280)
    }
}

/// Ask / Allow / Deny picker for one permission of one website
struct SitePermissionPicker: View {
    let permission: SitePermission
    let host: String
    var store: SitePermissionStore

    var body: some View {
        Picker(selection: Binding(
            get: { store.decision(for: permission, host: host) },
            set: { store.setDecision($0, for: permission, host: host) }
        )) {
            ForEach(SitePermissionDecision.allCases) { decision in
                Text(decision.title).tag(decision)
            }
        } label: {
            Label(permission.title, systemImage: permission.systemImage)
        }
    }
}
