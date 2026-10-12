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
- [ ] Grid Layout

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
