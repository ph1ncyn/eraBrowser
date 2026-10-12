//
//  EraAIChat.swift
//  Browser
//
//  Created by ph1ncyn on 10/12/26.
//

import SwiftUI
import WebKit

/// The eraAI conversation of a browser window
@Observable
final class EraAIChat {

    var messages: [EraAIMessage] = []
    var input = ""
    var isResponding = false
    var errorMessage: String?

    /// Send the current page's text (and selection) with each question
    var includePageContext: Bool = UserDefaults.standard.bool(forKey: EraAISettings.includePageKey) {
        didSet {
            UserDefaults.standard.set(includePageContext, forKey: EraAISettings.includePageKey)
        }
    }

    @ObservationIgnored private var responseTask: Task<Void, Never>?

    /// Sends a question to eraAI
    /// - Parameters:
    ///   - text: The question. If `nil`, the text field's content is sent.
    ///   - tab: The tab whose page is used as context
    func send(_ text: String? = nil, about tab: BrowserTab?) {
        let prompt = (text ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isResponding else { return }
        if text == nil {
            input = ""
        }

        errorMessage = nil
        let history = messages.suffix(EraAISettings.maxHistoryMessages)
        messages.append(EraAIMessage(role: .user, content: prompt))
        let answer = EraAIMessage(role: .assistant, content: "")
        messages.append(answer)
        isResponding = true

        let includePageContext = includePageContext
        responseTask = Task { @MainActor [weak self] in
            var page: EraAIPageContext? = nil
            if includePageContext {
                page = await EraAIPageContext.capture(from: tab)
            }
            let request = EraAIChat.requestMessages(history: Array(history), prompt: prompt, page: page)

            do {
                for try await delta in EraAIClient.current.streamChat(request) {
                    self?.append(delta, to: answer.id)
                }
            } catch {
                if !Task.isCancelled {
                    self?.errorMessage = error.localizedDescription
                }
            }
            self?.finishResponse(answer.id)
        }
    }

    /// Stops the answer being generated
    func stop() {
        responseTask?.cancel()
    }

    /// Clears the conversation
    func clear() {
        stop()
        messages.removeAll()
        errorMessage = nil
    }

    private func append(_ delta: String, to id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].content += delta
    }

    private func finishResponse(_ id: UUID) {
        if let index = messages.firstIndex(where: { $0.id == id }), messages[index].content.isEmpty {
            messages.remove(at: index)
        }
        isResponding = false
        responseTask = nil
    }

    /// Builds the messages sent to the server: system prompt (+ page), previous messages and the question
    static func requestMessages(history: [EraAIMessage], prompt: String, page: EraAIPageContext?) -> [EraAIMessage] {
        var system = EraAISettings.systemPrompt
        if let page {
            system += "\n\n" + page.description
        }

        var request = [EraAIMessage(role: .system, content: system)]
        request += history.filter { !$0.content.isEmpty }
        request.append(EraAIMessage(role: .user, content: prompt))
        return request
    }
}

/// Text of the page the user is looking at, sent to eraAI as context
struct EraAIPageContext: CustomStringConvertible {
    let title: String
    let url: URL
    let text: String
    let selection: String

    var description: String {
        var description = """
        The user is viewing this web page in the era browser.
        Title: \(title)
        URL: \(url.absoluteString)
        """
        if !selection.isEmpty {
            description += "\n\nText selected by the user:\n\"\"\"\n\(selection)\n\"\"\""
        }
        if !text.isEmpty {
            description += "\n\nPage content (may be truncated):\n\"\"\"\n\(text)\n\"\"\""
        }
        return description
    }

    private static let script = """
    JSON.stringify({
        text: document.body ? document.body.innerText : "",
        selection: String(window.getSelection() || "")
    })
    """

    @MainActor
    static func capture(from tab: BrowserTab?) async -> EraAIPageContext? {
        guard let tab, tab.type == .web, let webView = tab.webview else { return nil }

        let json: String? = await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    print("⚠️ eraAI could not read the page: \(error.localizedDescription)")
                }
                continuation.resume(returning: result as? String)
            }
        }

        var text = ""
        var selection = ""
        if let data = json?.data(using: .utf8),
           let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: String] {
            text = object["text"] ?? ""
            selection = object["selection"] ?? ""
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > EraAISettings.maxPageCharacters {
            text = String(text.prefix(EraAISettings.maxPageCharacters)) + "\n[…]"
        }
        selection = String(selection.trimmingCharacters(in: .whitespacesAndNewlines).prefix(EraAISettings.maxPageCharacters))

        return EraAIPageContext(title: tab.title, url: tab.url, text: text, selection: selection)
    }
}
