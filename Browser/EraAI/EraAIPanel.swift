//
//  EraAIPanel.swift
//  Browser
//
//  Created by ph1ncyn on 10/12/26.
//

import SwiftUI

/// Side panel to chat with eraAI about the current page
struct EraAIPanel: View {

    @Environment(BrowserWindowState.self) var browserWindowState
    @Bindable var chat: EraAIChat

    @FocusState private var isInputFocused: Bool

    var currentTab: BrowserTab? {
        browserWindowState.currentSpace?.currentTab
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if chat.messages.isEmpty {
                emptyState
            } else {
                messageList
            }

            if let errorMessage = chat.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .textSelection(.enabled)
            }

            Divider()
            inputBar
        }
        .foregroundStyle(.primary)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 8))
        .onAppear { isInputFocused = true }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
            Text("eraAI")
                .font(.headline)

            Spacer()

            Toggle(isOn: $chat.includePageContext) {
                Image(systemName: "doc.text")
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .help(chat.includePageContext ? "Page content is sent with your questions" : "Page content is not sent")

            Button("Clear Conversation", systemImage: "trash") { chat.clear() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(chat.messages.isEmpty)

            Button("Close", systemImage: "xmark") {
                withAnimation(.browserDefault) {
                    browserWindowState.showEraAI = false
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Ask eraAI anything about this page")
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                quickAction("Summarize this page", systemImage: "text.alignleft")
                quickAction("Explain the selected text", systemImage: "text.cursor")
                quickAction("List the key points of this page", systemImage: "list.bullet")
            }
            .disabled(currentTab == nil)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func quickAction(_ prompt: String, systemImage: String) -> some View {
        Button {
            chat.send(prompt, about: currentTab)
        } label: {
            Label(prompt, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Messages
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(chat.messages) { message in
                        EraAIMessageRow(message: message, isResponding: chat.isResponding && message.id == chat.messages.last?.id)
                            .id(message.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: chat.messages.last?.content) {
                if let lastID = chat.messages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Input
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask eraAI…", text: $chat.input, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isInputFocused)
                .onSubmit { chat.send(about: currentTab) }

            if chat.isResponding {
                Button("Stop", systemImage: "stop.circle.fill") { chat.stop() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .font(.title2)
            } else {
                Button("Send", systemImage: "arrow.up.circle.fill") { chat.send(about: currentTab) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .font(.title2)
                    .disabled(chat.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(10)
    }
}

/// A message bubble of the eraAI conversation
struct EraAIMessageRow: View {
    let message: EraAIMessage
    let isResponding: Bool

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            Group {
                if message.content.isEmpty && isResponding {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(rendered)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                message.role == .user ? AnyShapeStyle(Color.accentColor.opacity(0.25)) : AnyShapeStyle(.quaternary.opacity(0.5)),
                in: .rect(cornerRadius: 10)
            )

            if message.role != .user { Spacer(minLength: 40) }
        }
    }

    /// The message with Markdown (bold, italic, code, links) rendered
    private var rendered: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: message.content, options: options)) ?? AttributedString(message.content)
    }
}
