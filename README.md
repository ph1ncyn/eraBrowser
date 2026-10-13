# era — a minimal browser with eraAI built in

![CleanShot 2025-10-08 at 3  44 10@2x Large](https://github.com/user-attachments/assets/0053365a-76c3-478b-aea5-ec8754e95c22)

## Motivation

A browser made to use with keystrokes but happen to have a pleasing UI with website specific custom themes built-in. Brings the vertical tabs from Arc, Website modifications by Zen Internet and Transparent Zen, Blazingly fast and efficient webkit rendering — and **eraAI**, an assistant that reads the page you are on.

era is based on [Zero](https://github.com/sameerasw/Zero) by sameerasw.

## Technologies

- _SwiftUI_: Powers the app's entire user interface.
- _SwiftData_: Persists data such as Spaces and Tabs.
- _WebKit_: The Browser's Engine.

<img width="1512" alt="Browser with No-Trace Window" src="https://github.com/user-attachments/assets/a761c164-ece6-4f6d-bba6-e012d307a670" />

## Features

- [x] Multiples Spaces
- [x] No-Trace Window
- [x] Temporary Window
- [x] Translate websites
- [x] History
- [x] Keyboard Shortcuts
- [x] Ad Blocker
- [x] Web Inspector
- [x] **Website search with autosuggestions _on some websistes_**

https://github.com/user-attachments/assets/90738982-651a-4991-8580-866325d1d128

- [x] Picture-in-Picutre
- [x] Built in custom website themes and transparency
- [x] Liquid glass and latest design to feel at home
- [x] Middle click
- [x] Smooth tab switching and UI animations
- [x] Focus mode with 0 visible UI for an immersive browsing experience
- [x] Search in Page
- [x] Reorder Tabs By Dragging
- [x] Export Page as PDF, Image, etc...  
- [x] Pinned Tabs    
- [x] Tab Suspension 
- [x] Multiple Windows
- [x] Reopen Closed Tabs (⌘⇧T, History → Recently Closed) with their back/forward history
- [x] **eraAI** side panel (⌘⇧E): chat about the current page, summarize, explain selected text (right click → Ask eraAI)
- [x] **Split View**: up to 4 tabs side by side, stacked or in a grid (⌘\\, right click a tab → Open in Split View)
- [x] **Extensions** from the Chrome Web Store and Firefox Add-ons (see below)
- [x] Session restore: tabs, selected tab and back/forward history come back after a relaunch; closing the last tab keeps the window open
- [x] Per-site camera / microphone / location permissions (address bar → slider icon, Settings → Websites)
- [x] Choice of search engine: Google, DuckDuckGo, Bing, Brave, Yandex, Ecosia, Startpage, Kagi, Perplexity or custom

## Extensions

era loads WebExtensions with WebKit's `WKWebExtension` (the engine behind Safari extensions, macOS 15.4+).
Chrome (Manifest V2/V3) and Firefox extensions use the same WebExtensions format, so most of them work as is:

- open an extension's page on **chromewebstore.google.com** or **addons.mozilla.org** and press **+** in the sidebar, or
- paste the store link in **Settings → Extensions**, or install a `.crx` / `.xpi` / `.zip` file or an unpacked folder.

Extension buttons appear in the sidebar toolbar (right click → Extension Settings). Extensions don't run in No-Trace windows.
APIs WebKit doesn't implement are unavailable — notably blocking `webRequest` (use uBlock Origin Lite instead of uBlock Origin),
`chrome.debugger` and other Chrome-only APIs. Orion goes further by implementing such APIs itself.

## eraAI

The eraAI panel talks to any server that implements the OpenAI-compatible Chat Completions API
(`POST <endpoint>/chat/completions`, streaming or not). The question is sent with the page title, URL,
selected text and page text (toggle with the 📄 button in the panel).

1. Start a server — the bundled example lets you plug your own model into one Python function:
   ```sh
   cd eraAI-server
   pip install -r requirements.txt
   python server.py   # http://127.0.0.1:8000/v1
   ```
   See [`eraAI-server/README.md`](eraAI-server/README.md). Ollama, LM Studio, vLLM or llama.cpp work too.
2. In era: **Settings → eraAI** set the endpoint, model and (optional) API key, then press *Test Connection*.
   The API key is stored in the Keychain.

## Building

The project links against the system-provided WebKit, so a custom WebKit.framework checkout is not required. Open `era.xcodeproj` and build the `era` scheme with the latest Xcode on macOS 26.

Before the first build, select your own team in *Signing & Capabilities* (the project still has the upstream team ID).
The bundle identifier is `com.ph1ncyn.era`, so era keeps its own spaces, tabs and settings, separate from Zero.

Credits to [sameerasw/Zero](https://github.com/sameerasw/Zero) and [LeonardoLarranaga/Browser](https://github.com/LeonardoLarranaga/Browser) for the open browser source <3
