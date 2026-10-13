//
//  SearchEngineSection.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import SwiftUI

/// Section to choose the default search engine
struct SearchEngineSection: View {
    @AppStorage(DefaultSearchEngine.userDefaultsKey) var engine = DefaultSearchEngine.google
    @AppStorage(DefaultSearchEngine.customTemplateKey) var customTemplate = ""

    var body: some View {
        Section {
            Picker(selection: $engine) {
                ForEach(DefaultSearchEngine.allCases) { engine in
                    Text(engine.title).tag(engine)
                }
            } label: {
                Label("Search Engine", systemImage: "magnifyingglass")
            }

            if engine == .custom {
                TextField("Search URL", text: $customTemplate, prompt: Text("https://example.com/search?q=%s"))
                if !customTemplate.contains("%s") {
                    Text("Use %s where the search terms go. Google is used until the URL is valid.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Used by the address bar and by \"Search With…\" when you right click selected text.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
