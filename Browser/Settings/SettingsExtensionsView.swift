//
//  SettingsExtensionsView.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import SwiftUI
import UniformTypeIdentifiers
import WebKit

/// Install and manage Chrome / Firefox / Safari web extensions
struct SettingsExtensionsView: View {
    var manager = WebExtensionsManager.shared

    @State var storeLink = ""
    @State var isInstalling = false
    @State var errorMessage: String?

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Store Link", text: $storeLink, prompt: Text("chromewebstore.google.com/detail/… or addons.mozilla.org/…/addon/…"))
                        .onSubmit(installFromStore)
                    Button("Install", action: installFromStore)
                        .disabled(storeLink.trimmingCharacters(in: .whitespaces).isEmpty || isInstalling)
                }

                HStack {
                    Button("Install From File…", systemImage: "doc.zipper") { chooseAndInstall(directories: false) }
                    Button("Install Unpacked Folder…", systemImage: "folder") { chooseAndInstall(directories: true) }
                    if isInstalling {
                        ProgressView().controlSize(.small)
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Add Extensions")
            } footer: {
                Text("era runs WebExtensions with WebKit, the engine of Safari: most Chrome (Manifest V2/V3) and Firefox extensions work. APIs WebKit doesn't support, such as blocking webRequest, aren't available (e.g. use uBlock Origin Lite instead of uBlock Origin). You can also open an extension's store page and press the + button in the sidebar. Extensions don't run in No-Trace windows.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Installed") {
                if manager.installed.isEmpty {
                    Text("No extensions installed")
                        .foregroundStyle(.secondary)
                }
                ForEach(manager.installed) { item in
                    InstalledExtensionRow(item: item, manager: manager)
                }
            }
        }
        .formStyle(.grouped)
    }

    func installFromStore() {
        let link = storeLink
        install {
            try await manager.install(fromStore: link)
            storeLink = ""
        }
    }

    func chooseAndInstall(directories: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = directories
        panel.canChooseFiles = !directories
        panel.allowsMultipleSelection = false
        panel.message = directories ? "Choose a folder containing a manifest.json" : "Choose a .crx, .xpi or .zip extension"
        if !directories {
            panel.allowedContentTypes = ["crx", "xpi", "zip"].compactMap { UTType(filenameExtension: $0) }
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        install {
            try await manager.install(fromFile: url)
        }
    }

    private func install(_ operation: @escaping @MainActor () async throws -> Void) {
        isInstalling = true
        errorMessage = nil
        Task { @MainActor in
            do {
                try await operation()
            } catch {
                errorMessage = error.localizedDescription
            }
            isInstalling = false
        }
    }
}

/// One installed extension: icon, name, version, enable toggle, settings and remove
struct InstalledExtensionRow: View {
    let item: InstalledWebExtension
    var manager: WebExtensionsManager

    var body: some View {
        let context = manager.context(for: item)
        let webExtension = context?.webExtension

        HStack(alignment: .top, spacing: 10) {
            Group {
                if let icon = webExtension?.icon(for: CGSize(width: 32, height: 32)) {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.title2)
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(webExtension?.displayName ?? item.fileName)
                        .font(.headline)
                    if let version = webExtension?.displayVersion {
                        Text(version)
                            .foregroundStyle(.secondary)
                    }
                }
                if let description = webExtension?.displayDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let source = item.sourceDescription {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let error = manager.loadErrors[item.id] {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                if let warnings = webExtension?.errors, !warnings.isEmpty {
                    Text(warnings.map { $0.localizedDescription }.joined(separator: "\n"))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }

            Spacer()

            if let context, context.optionsPageURL != nil {
                Button("Settings", systemImage: "gearshape") {
                    manager.openOptionsPage(for: context)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Extension Settings")
            }

            Toggle("Enabled", isOn: Binding(
                get: { item.isEnabled },
                set: { manager.setEnabled($0, for: item) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)

            Button("Remove", systemImage: "trash") {
                manager.uninstall(item)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Remove Extension")
        }
    }
}
