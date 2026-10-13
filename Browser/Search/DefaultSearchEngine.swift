//
//  DefaultSearchEngine.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import SwiftUI

/// The search engine used by the address bar and by "Search With…" in the context menu
enum DefaultSearchEngine: String, CaseIterable, Identifiable {
    case google
    case duckDuckGo
    case bing
    case brave
    case yandex
    case ecosia
    case startpage
    case kagi
    case perplexity
    case custom

    static let userDefaultsKey = "default_search_engine"
    static let customTemplateKey = "custom_search_engine_template"

    var id: String { rawValue }

    /// The engine selected in Settings → General
    static var current: DefaultSearchEngine {
        DefaultSearchEngine(rawValue: UserDefaults.standard.string(forKey: userDefaultsKey) ?? "") ?? .google
    }

    var title: String {
        switch self {
        case .google: return "Google"
        case .duckDuckGo: return "DuckDuckGo"
        case .bing: return "Bing"
        case .brave: return "Brave Search"
        case .yandex: return "Yandex"
        case .ecosia: return "Ecosia"
        case .startpage: return "Startpage"
        case .kagi: return "Kagi"
        case .perplexity: return "Perplexity"
        case .custom: return "Custom"
        }
    }

    /// Search URL, `%s` is replaced by the query
    var searchTemplate: String {
        switch self {
        case .google: return "https://www.google.com/search?q=%s"
        case .duckDuckGo: return "https://duckduckgo.com/?q=%s"
        case .bing: return "https://www.bing.com/search?q=%s"
        case .brave: return "https://search.brave.com/search?q=%s"
        case .yandex: return "https://yandex.ru/search/?text=%s"
        case .ecosia: return "https://www.ecosia.org/search?q=%s"
        case .startpage: return "https://www.startpage.com/do/search?q=%s"
        case .kagi: return "https://kagi.com/search?q=%s"
        case .perplexity: return "https://www.perplexity.ai/search?q=%s"
        case .custom:
            let template = UserDefaults.standard.string(forKey: Self.customTemplateKey) ?? ""
            return template.contains("%s") ? template : DefaultSearchEngine.google.searchTemplate
        }
    }

    /// Suggestions URL returning the OpenSearch JSON format `["query", ["suggestion", …]]`
    var suggestionsTemplate: String? {
        switch self {
        case .google: return "https://suggestqueries.google.com/complete/search?client=firefox&q=%s"
        case .duckDuckGo: return "https://duckduckgo.com/ac/?q=%s&type=list"
        case .bing: return "https://api.bing.com/osjson.aspx?query=%s"
        case .brave: return "https://search.brave.com/api/suggest?q=%s"
        case .yandex: return "https://suggest.yandex.ru/suggest-ff.cgi?part=%s"
        case .ecosia: return "https://ac.ecosia.org/autocomplete?q=%s&type=list"
        case .startpage, .kagi, .perplexity, .custom: return nil
        }
    }

    var color: Color {
        switch self {
        case .google: return Color(hex: "#5383EC") ?? .blue
        case .duckDuckGo: return Color(hex: "#DE5833") ?? .orange
        case .bing: return Color(hex: "#02B7E9") ?? .cyan
        case .brave: return Color(hex: "#FB542B") ?? .orange
        case .yandex: return Color(hex: "#FC3F1D") ?? .red
        case .ecosia: return Color(hex: "#36ACB8") ?? .teal
        case .startpage: return Color(hex: "#6573FF") ?? .indigo
        case .kagi: return Color(hex: "#FFB319") ?? .yellow
        case .perplexity: return Color(hex: "#20808D") ?? .teal
        case .custom: return .gray
        }
    }

    var searcher: WebsiteSearcher {
        DefaultSearchEngineSearcher(engine: self)
    }

    /// The search results URL for a query
    func searchURL(for query: String) -> URL {
        Self.url(from: searchTemplate, query: query)
            ?? URL(string: "https://www.google.com/search?q=\(Self.encode(query))")!
    }

    static func url(from template: String, query: String) -> URL? {
        URL(string: template.replacingOccurrences(of: "%s", with: encode(query)))
    }

    /// Percent-encodes everything but unreserved characters, so `&`, `#`, `+`… stay part of the query
    static func encode(_ query: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
    }
}

/// `WebsiteSearcher` for the default search engine (address bar suggestions)
struct DefaultSearchEngineSearcher: WebsiteSearcher {
    let engine: DefaultSearchEngine

    var title: String { engine.title }
    var color: Color { engine.color }

    func queryURL(for query: String) -> URL? {
        guard let template = engine.suggestionsTemplate else { return nil }
        return DefaultSearchEngine.url(from: template, query: query)
    }

    func itemURL(for query: String) -> URL {
        engine.searchURL(for: query)
    }

    func parseSearchSuggestions(from result: String) throws -> [SearchSuggestion] {
        // The data is decoded as Latin-1 by the fetcher; restore the UTF-8 text first
        let data = result.data(using: .isoLatin1) ?? Data(result.utf8)
        guard let array = (try? JSONSerialization.jsonObject(with: data)) as? [Any],
              array.count > 1,
              let suggestions = array[1] as? [Any]
        else { return [] }

        return suggestions
            .compactMap { $0 as? String }
            .prefix(8)
            .map { SearchSuggestion($0, itemURL: itemURL(for: $0)) }
    }
}
