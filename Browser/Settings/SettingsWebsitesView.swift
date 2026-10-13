//
//  SettingsWebsitesView.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import SwiftUI

/// Saved camera / microphone / location decisions for every website
struct SettingsWebsitesView: View {
    var store = SitePermissionStore.shared

    var body: some View {
        Form {
            if store.hosts.isEmpty {
                Text("No website permissions saved yet. When a website asks for your camera, microphone or location, your answer appears here.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.hosts, id: \.self) { host in
                    Section {
                        ForEach(SitePermission.allCases) { permission in
                            SitePermissionPicker(permission: permission, host: host, store: store)
                        }
                    } header: {
                        HStack {
                            Text(host)
                            Spacer()
                            Button("Remove", systemImage: "trash") {
                                store.reset(host: host)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Button("Reset All Websites", role: .destructive) {
                    store.resetAll()
                }
            }
        }
        .formStyle(.grouped)
    }
}
