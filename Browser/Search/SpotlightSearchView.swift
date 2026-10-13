//
//  SpotlightSearchView.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import SwiftUI
import SwiftData

/// A result row of the Spotlight-style search panel
struct SpotlightResult: Identifiable {
    enum Kind {
        /// Search the query, or open it if it is an address
        case search(SearchSuggestion)
        /// A search suggestion from the search engine
        case suggestion(SearchSuggestion)
        /// An open tab of the current space
        case tab(BrowserTab)
        /// A history entry
        case history(BrowserHistoryEntry)
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String?
    let accessory: String?
}

/// A group of results with an optional header
struct SpotlightSection: Identifiable {
    let id: String
    let title: String?
    let results: [SpotlightResult]
}

/// Spotlight-style search panel: floating in the middle of the window, with open tabs, history and suggestions
struct SpotlightSearchView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(BrowserWindowState.self) var browserWindowState

    @State var searchManager = SearchManager()
    @State var highlightedIndex = 0
    @State var historyEntries: [BrowserHistoryEntry] = []
    @State var appeared = false
    @FocusState var isFieldFocused: Bool

    private var query: String {
        searchManager.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEditingCurrentURL: Bool {
        browserWindowState.searchOpenLocation == .fromURLBar
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Dimmed background, click to close
                Color.black.opacity(colorScheme == .dark ? 0.3 : 0.12)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)

                panel
                    .frame(width: min(680, max(geometry.size.width - 48, 300)))
                    .padding(.top, max(56, geometry.size.height * 0.16))
                    .scaleEffect(appeared ? 1 : 0.96, anchor: .top)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            searchManager.setInitialValuesFromWindowState(browserWindowState)
            fetchHistory()
            isFieldFocused = true
            if isEditingCurrentURL {
                DispatchQueue.main.async {
                    NSApplication.shared.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: nil)
                }
            }
            withAnimation(.snappy(duration: 0.22)) {
                appeared = true
            }
        }
        // ⌘T while editing the address (or ⌘L from New Tab) switches the mode in place
        .onChange(of: browserWindowState.searchOpenLocation) { _, newValue in
            guard newValue != nil else { return }
            searchManager.resetWebsiteSearcher()
            searchManager.searchText = ""
            searchManager.favicon = nil
            searchManager.setInitialValuesFromWindowState(browserWindowState)
            if isEditingCurrentURL {
                DispatchQueue.main.async {
                    NSApplication.shared.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: nil)
                }
            }
        }
        .onChange(of: searchManager.searchText) { _, newValue in
            highlightedIndex = 0
            fetchHistory()
            if newValue.last != " " {
                searchManager.fetchSearchSuggestions(newValue)
            }
        }
        .onKeyPress(.escape) {
            close()
            return .handled
        }
        .onKeyPress(.return, phases: .down) { press in
            openHighlighted(inNewTab: press.modifiers.contains(.command))
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveHighlight(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveHighlight(by: 1)
            return .handled
        }
        .onKeyPress(.tab, action: searchManager.handleTab)
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(spacing: 0) {
            searchField

            let sections = self.sections
            if !sections.isEmpty {
                Divider()
                    .opacity(0.6)
                resultsList(sections)
                Divider()
                    .opacity(0.6)
                keyboardHints
            }
        }
        .foregroundStyle(.primary)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.28), radius: 32, y: 14)
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            fieldIcon
                .frame(width: 22, height: 22)

            if searchManager.isUsingWebsiteSearcher {
                Text(searchManager.activeWebsiteSearcher.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(searchManager.activeWebsiteSearcher.color, in: .capsule)
            }

            TextField(isEditingCurrentURL ? "Edit address" : "Search or enter address", text: $searchManager.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 22))
                .focused($isFieldFocused)

            if !searchManager.isUsingWebsiteSearcher, let matchedWebsiteSearcher = searchManager.matchedWebsiteSearcher {
                HStack(spacing: 6) {
                    Text("Search \(matchedWebsiteSearcher.title)")
                    KeyCap("⇥")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            } else if !searchManager.searchText.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    searchManager.searchText = ""
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 60)
    }

    @ViewBuilder
    private var fieldIcon: some View {
        if isEditingCurrentURL, let favicon = searchManager.favicon, let image = NSImage(data: favicon) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: 5))
        } else {
            Image(systemName: "magnifyingglass")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func resultsList(_ sections: [SpotlightSection]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(sections) { section in
                        if let title = section.title {
                            Text(title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                                .padding(.bottom, 2)
                        }
                        ForEach(section.results) { result in
                            let resultIndex = self.index(of: result, in: sections)
                            SpotlightResultRow(
                                result: result,
                                isHighlighted: resultIndex == highlightedIndex,
                                accentColor: searchManager.accentColor
                            )
                            .id(result.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                open(result, inNewTab: NSEvent.modifierFlags.contains(.command))
                            }
                            .onHover { hovering in
                                if hovering { highlightedIndex = resultIndex }
                            }
                        }
                    }
                }
                .padding(8)
            }
            .scrollIndicators(.never)
            .frame(height: min(400, Self.estimatedHeight(of: sections)))
            .onChange(of: highlightedIndex) { _, newValue in
                let flat = sections.flatMap(\.results)
                guard flat.indices.contains(newValue) else { return }
                proxy.scrollTo(flat[newValue].id)
            }
        }
    }

    /// Height of the results list, so the panel hugs its content
    private static func estimatedHeight(of sections: [SpotlightSection]) -> CGFloat {
        sections.reduce(16) { height, section in
            height
                + (section.title == nil ? 0 : 26)
                + section.results.reduce(0) { $0 + ($1.subtitle == nil ? 38 : 46) + 2 }
        }
    }

    private var keyboardHints: some View {
        HStack(spacing: 14) {
            hint("Open", keys: "↩")
            hint("New Tab", keys: "⌘↩")
            hint("Search a Site", keys: "⇥")
            Spacer()
            hint("Close", keys: "esc")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .frame(height: 30)
    }

    private func hint(_ title: String, keys: String) -> some View {
        HStack(spacing: 5) {
            KeyCap(keys)
            Text(title)
        }
    }

    // MARK: - Results

    private var sections: [SpotlightSection] {
        var sections: [SpotlightSection] = []

        guard !query.isEmpty else {
            // Recently visited pages
            let recent = historyEntries.prefix(5).map(historyResult)
            if !recent.isEmpty {
                sections.append(SpotlightSection(id: "recent", title: "Recently Visited", results: Array(recent)))
            }
            return sections
        }

        // Top hit: open the address, or search the query
        let searcher = searchManager.activeWebsiteSearcher
        let topSuggestion = SearchSuggestion(query, itemURL: searcher.itemURL(for: query))
        let topHit: SpotlightResult = topSuggestion.isURLValid && !searchManager.isUsingWebsiteSearcher
            ? SpotlightResult(id: "top", kind: .search(topSuggestion), title: query, subtitle: "Open website", accessory: nil)
            : SpotlightResult(id: "top", kind: .search(topSuggestion), title: query, subtitle: "Search with \(searcher.title)", accessory: nil)
        sections.append(SpotlightSection(id: "top", title: nil, results: [topHit]))

        guard !searchManager.isUsingWebsiteSearcher else {
            appendSuggestions(to: &sections)
            return sections
        }

        // Open tabs of the current space
        let lowercasedQuery = query.lowercased()
        let tabs = (browserWindowState.currentSpace?.allTabs ?? [])
            .filter { $0.type == .web && $0 != browserWindowState.currentSpace?.currentTab }
            .filter { $0.title.lowercased().contains(lowercasedQuery) || $0.url.absoluteString.lowercased().contains(lowercasedQuery) }
            .prefix(4)
        if !tabs.isEmpty {
            sections.append(SpotlightSection(id: "tabs", title: "Open Tabs", results: tabs.map { tab in
                SpotlightResult(id: "tab-\(tab.id)", kind: .tab(tab), title: tab.title, subtitle: tab.url.cleanHost, accessory: "Switch to Tab")
            }))
        }

        // History, without pages already open
        let openURLs = Set(tabs.map(\.url))
        let history = historyEntries.filter { !openURLs.contains($0.url) }.prefix(4).map(historyResult)
        if !history.isEmpty {
            sections.append(SpotlightSection(id: "history", title: "History", results: Array(history)))
        }

        appendSuggestions(to: &sections)
        return sections
    }

    private func appendSuggestions(to sections: inout [SpotlightSection]) {
        var seen = Set([query.lowercased()])
        let suggestions = searchManager.searchSuggestions
            .dropFirst()
            .filter { seen.insert($0.title.lowercased()).inserted }
            .prefix(6)
        guard !suggestions.isEmpty else { return }
        sections.append(SpotlightSection(id: "suggestions", title: "\(searchManager.activeWebsiteSearcher.title) Suggestions", results: suggestions.map { suggestion in
            SpotlightResult(id: "suggestion-\(suggestion.title)", kind: .suggestion(suggestion), title: suggestion.title, subtitle: nil, accessory: nil)
        }))
    }

    private func historyResult(_ entry: BrowserHistoryEntry) -> SpotlightResult {
        SpotlightResult(
            id: "history-\(entry.id)",
            kind: .history(entry),
            title: entry.title.isEmpty ? entry.url.cleanHost : entry.title,
            subtitle: entry.url.absoluteString,
            accessory: entry.date.formatted(.relative(presentation: .named))
        )
    }

    private func index(of result: SpotlightResult, in sections: [SpotlightSection]) -> Int {
        sections.flatMap(\.results).firstIndex { $0.id == result.id } ?? -1
    }

    /// Latest history entries matching the query, one per address
    private func fetchHistory() {
        var descriptor = FetchDescriptor<BrowserHistoryEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 500
        let entries = (try? modelContext.fetch(descriptor)) ?? []

        let lowercasedQuery = query.lowercased()
        var seen = Set<URL>()
        historyEntries = entries
            .filter { lowercasedQuery.isEmpty || $0.title.lowercased().contains(lowercasedQuery) || $0.url.absoluteString.lowercased().contains(lowercasedQuery) }
            .filter { seen.insert($0.url).inserted }
            .prefix(8)
            .map { $0 }
    }

    // MARK: - Actions

    private func moveHighlight(by offset: Int) {
        let count = sections.reduce(0) { $0 + $1.results.count }
        guard count > 0 else { return }
        highlightedIndex = (highlightedIndex + offset + count) % count
    }

    private func openHighlighted(inNewTab: Bool) {
        let results = sections.flatMap(\.results)
        if results.indices.contains(highlightedIndex) {
            open(results[highlightedIndex], inNewTab: inNewTab)
        } else if !query.isEmpty {
            let suggestion = SearchSuggestion(query, itemURL: searchManager.activeWebsiteSearcher.itemURL(for: query))
            searchManager.searchAction(suggestion, browserWindowState: browserWindowState, using: modelContext, inNewTab: inNewTab ? true : nil)
        }
    }

    private func open(_ result: SpotlightResult, inNewTab: Bool) {
        let newTab: Bool? = inNewTab ? true : nil
        switch result.kind {
        case .search(let suggestion), .suggestion(let suggestion):
            searchManager.searchAction(suggestion, browserWindowState: browserWindowState, using: modelContext, inNewTab: newTab)
        case .history(let entry):
            let suggestion = SearchSuggestion(entry.url.absoluteString, itemURL: entry.url)
            searchManager.searchAction(suggestion, browserWindowState: browserWindowState, using: modelContext, inNewTab: newTab)
        case .tab(let tab):
            tab.isSuspended = false
            browserWindowState.currentSpace?.currentTab = tab
            close()
        }
    }

    private func close() {
        browserWindowState.searchOpenLocation = .none
    }
}

/// A row of the Spotlight panel
struct SpotlightResultRow: View {
    let result: SpotlightResult
    let isHighlighted: Bool
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .lineLimit(1)
                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .opacity(0.7)
                }
            }

            Spacer(minLength: 8)

            if let accessory = result.accessory {
                Text(accessory)
                    .font(.caption)
                    .opacity(0.7)
            }

            if isHighlighted {
                Image(systemName: "return")
                    .font(.caption.weight(.semibold))
                    .opacity(0.7)
            }
        }
        .foregroundStyle(isHighlighted ? Color.white : Color.primary)
        .padding(.horizontal, 10)
        .frame(height: result.subtitle == nil ? 38 : 46)
        .background(isHighlighted ? AnyShapeStyle(accentColor.opacity(0.9)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 12))
    }

    @ViewBuilder
    private var icon: some View {
        switch result.kind {
        case .search(let suggestion):
            symbol(suggestion.isURLValid ? "globe" : "magnifyingglass")
        case .suggestion:
            symbol("magnifyingglass")
        case .tab(let tab):
            favicon(tab.favicon, fallback: "square.on.square")
        case .history(let entry):
            favicon(entry.favicon, fallback: "clock")
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 26, height: 26)
            .background(isHighlighted ? AnyShapeStyle(.white.opacity(0.2)) : AnyShapeStyle(.quaternary), in: .rect(cornerRadius: 7))
    }

    @ViewBuilder
    private func favicon(_ data: Data?, fallback: String) -> some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(3)
                .background(.white.opacity(0.9), in: .rect(cornerRadius: 7))
        } else {
            symbol(fallback)
        }
    }
}

/// A keyboard key, e.g. ⌘ or esc
struct KeyCap: View {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(key)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.quaternary, in: .rect(cornerRadius: 4))
    }
}
