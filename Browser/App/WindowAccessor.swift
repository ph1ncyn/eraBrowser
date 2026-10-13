//
//  WindowAccessor.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import SwiftUI

/// Reports the `NSWindow` hosting a SwiftUI view
struct WindowAccessor: NSViewRepresentable {
    let onWindowChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> WindowAccessorView {
        let view = WindowAccessorView()
        view.onWindowChange = onWindowChange
        return view
    }

    func updateNSView(_ nsView: WindowAccessorView, context: Context) {}
}

final class WindowAccessorView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
