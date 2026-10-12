//
//  SettingsEraAIView.swift
//  Browser
//
//  Created by ph1ncyn on 10/12/26.
//

import SwiftUI

/// Settings for the eraAI assistant
struct SettingsEraAIView: View {

    @AppStorage(EraAISettings.endpointKey) var endpoint = EraAISettings.defaultEndpoint
    @AppStorage(EraAISettings.modelKey) var model = EraAISettings.defaultModel
    @AppStorage(EraAISettings.systemPromptKey) var systemPrompt = EraAISettings.defaultSystemPrompt
    @AppStorage(EraAISettings.includePageKey) var includePage = true

    @State var apiKey = EraAISettings.apiKey

    enum TestState: Equatable {
        case idle
        case testing
        case success(String)
        case failure(String)
    }
    @State var testState = TestState.idle

    var body: some View {
        Form {
            Section {
                TextField("Endpoint", text: $endpoint, prompt: Text(EraAISettings.defaultEndpoint))
                TextField("Model", text: $model, prompt: Text(EraAISettings.defaultModel))
                SecureField("API Key", text: $apiKey, prompt: Text("Optional"))
                    .onChange(of: apiKey) { _, newValue in
                        EraAISettings.apiKey = newValue
                    }
            } header: {
                Text("Server")
            } footer: {
                Text("eraAI uses the OpenAI-compatible Chat Completions API: requests are sent to `<endpoint>/chat/completions`. See `eraAI-server/` in the repository for a Python server you can plug your model into. The API key is stored in the Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Send Page Content With Questions", systemImage: "doc.text", isOn: $includePage)
                VStack(alignment: .leading) {
                    Text("System Prompt")
                    TextEditor(text: $systemPrompt)
                        .font(.body)
                        .frame(minHeight: 80)
                }
                Button("Reset System Prompt") {
                    systemPrompt = EraAISettings.defaultSystemPrompt
                }
                .disabled(systemPrompt == EraAISettings.defaultSystemPrompt)
            }

            Section {
                HStack {
                    Button("Test Connection", action: testConnection)
                        .disabled(testState == .testing)

                    switch testState {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView().controlSize(.small)
                    case .success(let answer):
                        Label(answer, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .lineLimit(2)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.octagon.fill")
                            .foregroundStyle(.red)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    func testConnection() {
        testState = .testing
        Task { @MainActor in
            var answer = ""
            do {
                let messages = [EraAIMessage(role: .user, content: "Reply with one short sentence to confirm you are working.")]
                for try await delta in EraAIClient.current.streamChat(messages) {
                    answer += delta
                }
                testState = .success(answer.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }
}

#Preview {
    SettingsEraAIView()
}
