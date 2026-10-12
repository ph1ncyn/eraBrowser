//
//  EraAISettings.swift
//  Browser
//
//  Created by ph1ncyn on 10/12/26.
//

import Foundation
import Security

/// Settings for the eraAI assistant.
/// The endpoint, model and prompt live in `UserDefaults`; the API key is stored in the Keychain.
enum EraAISettings {
    static let endpointKey = "era_ai_endpoint"
    static let modelKey = "era_ai_model"
    static let systemPromptKey = "era_ai_system_prompt"
    static let includePageKey = "era_ai_include_page"

    static let defaultEndpoint = "http://127.0.0.1:8000/v1"
    static let defaultModel = "era"
    static let defaultSystemPrompt = "You are eraAI, the assistant built into the era browser. Answer concisely and in the language the user writes in. When page content is provided, base your answer on it."

    /// Maximum number of characters of page text sent with a question
    static let maxPageCharacters = 15_000
    /// Maximum number of previous messages sent with a question
    static let maxHistoryMessages = 20

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            endpointKey: defaultEndpoint,
            modelKey: defaultModel,
            systemPromptKey: defaultSystemPrompt,
            includePageKey: true
        ])
    }

    static var endpoint: String { UserDefaults.standard.string(forKey: endpointKey) ?? defaultEndpoint }
    static var model: String { UserDefaults.standard.string(forKey: modelKey) ?? defaultModel }
    static var systemPrompt: String { UserDefaults.standard.string(forKey: systemPromptKey) ?? defaultSystemPrompt }

    // MARK: - API key (Keychain)
    private static let keychainService = "eraAI"
    private static let keychainAccount = "api_key"

    static var apiKey: String {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: keychainAccount,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data else { return "" }
            return String(decoding: data, as: UTF8.self)
        }
        set {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: keychainAccount
            ]
            SecItemDelete(query as CFDictionary)
            guard !newValue.isEmpty else { return }
            var attributes = query
            attributes[kSecValueData as String] = Data(newValue.utf8)
            let status = SecItemAdd(attributes as CFDictionary, nil)
            if status != errSecSuccess {
                print("⚠️ Could not save the eraAI API key to the Keychain: \(status)")
            }
        }
    }
}
