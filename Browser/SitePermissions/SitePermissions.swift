//
//  SitePermissions.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import SwiftUI

/// A device permission a website can request
enum SitePermission: String, CaseIterable, Identifiable {
    case camera
    case microphone
    case location

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .location: return "Location"
        }
    }

    var systemImage: String {
        switch self {
        case .camera: return "camera"
        case .microphone: return "mic"
        case .location: return "location"
        }
    }
}

/// What to do when a website requests a permission
enum SitePermissionDecision: String, CaseIterable, Identifiable {
    case ask
    case allow
    case deny

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask: return "Ask"
        case .allow: return "Allow"
        case .deny: return "Deny"
        }
    }
}

/// Stores the permission decisions per website (host), in `UserDefaults`
@Observable
final class SitePermissionStore {
    static let shared = SitePermissionStore()

    private static let userDefaultsKey = "site_permissions"

    /// host → permission → decision
    private(set) var decisions: [String: [String: String]]

    private init() {
        decisions = UserDefaults.standard.dictionary(forKey: Self.userDefaultsKey) as? [String: [String: String]] ?? [:]
    }

    /// Websites with at least one saved decision
    var hosts: [String] {
        decisions.keys.sorted()
    }

    static func normalizedHost(_ host: String) -> String {
        let host = host.lowercased()
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    func decision(for permission: SitePermission, host: String) -> SitePermissionDecision {
        let raw = decisions[Self.normalizedHost(host)]?[permission.rawValue] ?? ""
        return SitePermissionDecision(rawValue: raw) ?? .ask
    }

    func setDecision(_ decision: SitePermissionDecision, for permission: SitePermission, host: String) {
        let host = Self.normalizedHost(host)
        guard !host.isEmpty else { return }
        var siteDecisions = decisions[host] ?? [:]
        if decision == .ask {
            siteDecisions.removeValue(forKey: permission.rawValue)
        } else {
            siteDecisions[permission.rawValue] = decision.rawValue
        }
        decisions[host] = siteDecisions.isEmpty ? nil : siteDecisions
        save()
    }

    func reset(host: String) {
        decisions.removeValue(forKey: Self.normalizedHost(host))
        save()
    }

    func resetAll() {
        decisions.removeAll()
        save()
    }

    private func save() {
        UserDefaults.standard.set(decisions, forKey: Self.userDefaultsKey)
    }

    /// Resolves a request for one or more permissions.
    /// A saved "deny" for any of them denies the request, "allow" for all of them grants it,
    /// otherwise the user is asked (and may remember the answer).
    /// - Parameters:
    ///   - window: Window to attach the prompt to
    ///   - completion: `true` to grant
    func request(_ permissions: [SitePermission], host: String, in window: NSWindow?, completion: @escaping (Bool) -> Void) {
        let saved = permissions.map { decision(for: $0, host: host) }
        if saved.contains(.deny) {
            completion(false)
            return
        }
        if saved.allSatisfy({ $0 == .allow }) {
            completion(true)
            return
        }

        let names = ListFormatter.localizedString(byJoining: permissions.map { $0.title.lowercased() })
        let alert = NSAlert()
        alert.messageText = "\"\(Self.normalizedHost(host))\" wants to use your \(names)"
        alert.informativeText = "You can change this later in the site settings (the slider icon in the address bar) or in Settings → Websites."
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Don't Allow")
        let rememberCheckbox = NSButton(checkboxWithTitle: "Remember for this website", target: nil, action: nil)
        rememberCheckbox.state = .on
        alert.accessoryView = rememberCheckbox

        let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
            let granted = response == .alertFirstButtonReturn
            if rememberCheckbox.state == .on {
                permissions.forEach { self.setDecision(granted ? .allow : .deny, for: $0, host: host) }
            }
            completion(granted)
        }

        if let window {
            alert.beginSheetModal(for: window, completionHandler: handleResponse)
        } else {
            handleResponse(alert.runModal())
        }
    }
}
