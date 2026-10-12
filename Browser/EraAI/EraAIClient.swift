//
//  EraAIClient.swift
//  Browser
//
//  Created by ph1ncyn on 10/12/26.
//

import Foundation

/// A message of the eraAI conversation
struct EraAIMessage: Identifiable, Equatable {
    enum Role: String {
        case system, user, assistant
    }

    let id = UUID()
    let role: Role
    var content: String
}

enum EraAIError: LocalizedError {
    case invalidEndpoint(String)
    case http(status: Int, body: String)
    case server(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let endpoint):
            return "Invalid eraAI endpoint: \"\(endpoint)\". Set it in Settings → eraAI."
        case .http(let status, let body):
            return body.isEmpty ? "eraAI server returned HTTP \(status)" : "eraAI server returned HTTP \(status): \(body.prefix(300))"
        case .server(let message):
            return "eraAI: \(message)"
        case .emptyResponse:
            return "eraAI returned an empty response."
        }
    }
}

/// Client for the eraAI server.
///
/// Speaks the OpenAI-compatible Chat Completions protocol (`POST {endpoint}/chat/completions`),
/// so it works with the bundled `eraAI-server` example, and with any compatible server
/// (Ollama, LM Studio, vLLM, llama.cpp...).
/// Streaming (Server-Sent Events) and plain JSON responses are both supported.
struct EraAIClient {
    var endpoint: String
    var model: String
    var apiKey: String

    /// Client built from the current settings
    static var current: EraAIClient {
        EraAIClient(endpoint: EraAISettings.endpoint, model: EraAISettings.model, apiKey: EraAISettings.apiKey)
    }

    /// Sends the conversation and streams back the assistant's answer piece by piece
    func streamChat(_ messages: [EraAIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(messages)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    guard (200..<300).contains(statusCode) else {
                        var body = ""
                        for try await line in bytes.lines {
                            body += line
                            if body.count > 1_000 { break }
                        }
                        throw EraAIError.http(status: statusCode, body: body)
                    }

                    var isEventStream = false
                    var plainBody = ""
                    var receivedText = false

                    for try await line in bytes.lines {
                        if line.hasPrefix("data:") {
                            isEventStream = true
                            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                            if payload == "[DONE]" { break }
                            if let delta = try Self.content(in: payload, choiceKey: "delta"), !delta.isEmpty {
                                receivedText = true
                                continuation.yield(delta)
                            }
                        } else if !isEventStream {
                            plainBody += line + "\n"
                        }
                    }

                    // The server answered with a single JSON object instead of a stream
                    if !isEventStream {
                        if let content = try Self.content(in: plainBody, choiceKey: "message"), !content.isEmpty {
                            receivedText = true
                            continuation.yield(content)
                        }
                    }

                    if !receivedText {
                        throw EraAIError.emptyResponse
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func makeRequest(_ messages: [EraAIMessage]) throws -> URLRequest {
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var url = URL(string: trimmedEndpoint), let scheme = url.scheme, ["http", "https"].contains(scheme) else {
            throw EraAIError.invalidEndpoint(trimmedEndpoint)
        }
        if !url.path().hasSuffix("/chat/completions") {
            url.append(path: "chat/completions")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Local models can take a while before the first token
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream, application/json", forHTTPHeaderField: "Accept")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Extracts `choices[0].<choiceKey>.content` from a JSON chunk.
    /// Throws if the server sent an `error` object.
    static func content(in json: String, choiceKey: String) throws -> String? {
        guard let data = json.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return nil }

        if let error = object["error"] {
            let message = (error as? [String: Any])?["message"] as? String ?? "\(error)"
            throw EraAIError.server(message)
        }

        let choice = (object["choices"] as? [[String: Any]])?.first
        return (choice?[choiceKey] as? [String: Any])?["content"] as? String
    }
}
