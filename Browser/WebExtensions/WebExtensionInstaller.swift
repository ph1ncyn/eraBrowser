//
//  WebExtensionInstaller.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import Foundation

/// Where an extension comes from: Chrome Web Store, Firefox Add-ons, or a local file/folder
enum WebExtensionSource: Equatable {
    case chromeWebStore(id: String)
    case firefoxAddons(slug: String)

    /// Recognizes a Chrome Web Store / Firefox Add-ons page URL, or a bare Chrome extension ID
    init?(_ input: String) {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // A bare Chrome extension ID: 32 characters a–p
        if input.range(of: "^[a-p]{32}$", options: .regularExpression) != nil {
            self = .chromeWebStore(id: input)
            return
        }

        guard let url = URL(string: input), let host = url.host()?.lowercased() else { return nil }

        if host == "chromewebstore.google.com" || host == "chrome.google.com" {
            let id = url.pathComponents.first { $0.range(of: "^[a-p]{32}$", options: .regularExpression) != nil }
            guard let id else { return nil }
            self = .chromeWebStore(id: id)
        } else if host == "addons.mozilla.org" {
            let components = url.pathComponents
            guard let index = components.firstIndex(of: "addon"), index + 1 < components.count else { return nil }
            self = .firefoxAddons(slug: components[index + 1])
        } else {
            return nil
        }
    }

    var storeName: String {
        switch self {
        case .chromeWebStore: return "Chrome Web Store"
        case .firefoxAddons: return "Firefox Add-ons"
        }
    }

    /// Stable identifier for the installed extension (`browser.runtime.id`)
    var preferredIdentifier: String? {
        switch self {
        case .chromeWebStore(let id): return id
        case .firefoxAddons: return nil
        }
    }

    var downloadURL: URL {
        switch self {
        case .chromeWebStore(let id):
            // Same endpoint Chrome uses; returns a .crx package
            return URL(string: "https://clients2.google.com/service/update2/crx?response=redirect&prodversion=130.0.0.0&acceptformat=crx2,crx3&x=id%3D\(id)%26installsource%3Dondemand%26uc")!
        case .firefoxAddons(let slug):
            let encodedSlug = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
            return URL(string: "https://addons.mozilla.org/firefox/downloads/latest/\(encodedSlug)/latest.xpi")!
        }
    }
}

enum WebExtensionInstallError: LocalizedError {
    case unsupportedInput
    case invalidPackage
    case download(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedInput:
            return "Paste a Chrome Web Store or Firefox Add-ons link, or a Chrome extension ID."
        case .invalidPackage:
            return "This file is not a valid .crx, .xpi or .zip extension package."
        case .download(let status):
            return "The store returned HTTP \(status) while downloading the extension."
        }
    }
}

enum WebExtensionPackage {
    /// Returns the ZIP archive inside a Chrome `.crx` package (Firefox `.xpi` files already are ZIP archives)
    static func zipData(from data: Data) throws -> Data {
        let bytes = [UInt8](data)
        if bytes.starts(with: [0x50, 0x4B]) { // "PK": already a ZIP
            return data
        }
        guard bytes.count > 16, bytes.starts(with: Array("Cr24".utf8)) else {
            throw WebExtensionInstallError.invalidPackage
        }

        func uint32(at offset: Int) -> Int {
            Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 | Int(bytes[offset + 2]) << 16 | Int(bytes[offset + 3]) << 24
        }

        let zipStart: Int
        switch uint32(at: 4) {
        case 2:
            // magic, version, public key length, signature length, public key, signature
            zipStart = 16 + uint32(at: 8) + uint32(at: 12)
        case 3:
            // magic, version, header length, header
            zipStart = 12 + uint32(at: 8)
        default:
            throw WebExtensionInstallError.invalidPackage
        }

        guard zipStart >= 0, zipStart + 1 < bytes.count, bytes[zipStart] == 0x50, bytes[zipStart + 1] == 0x4B else {
            throw WebExtensionInstallError.invalidPackage
        }
        return Data(bytes[zipStart...])
    }

    /// Downloads an extension package from its store
    static func download(_ source: WebExtensionSource) async throws -> Data {
        var request = URLRequest(url: source.downloadURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        guard (200..<300).contains(status), !data.isEmpty else {
            throw WebExtensionInstallError.download(status)
        }
        return data
    }
}
