//
//  LayoutOptionPicker.swift
//  Browser
//
//  Created by ph1ncyn on 10/14/26.
//

import SwiftUI

/// An option of a `LayoutOptionPicker`
struct LayoutOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var id: Value { value }
}

/// Visual picker: one card per option, each with a live mockup of the browser and a label
struct LayoutOptionPicker<Value: Hashable, Preview: View>: View {
    let title: String
    let systemImage: String
    var footer: String? = nil
    @Binding var selection: Value
    let options: [LayoutOption<Value>]
    @ViewBuilder let preview: (Value) -> Preview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)

            HStack(alignment: .top, spacing: 14) {
                ForEach(options) { option in
                    LayoutOptionCard(title: option.title, isSelected: selection == option.value) {
                        withAnimation(.snappy(duration: 0.2)) {
                            selection = option.value
                        }
                    } preview: {
                        preview(option.value)
                    }
                }
            }

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A selectable card with a preview and a title
struct LayoutOptionCard<Preview: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let preview: Preview

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                preview
                    .frame(width: 150, height: 96)
                    .padding(5)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.secondary.opacity(isHovering ? 0.5 : 0.2),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .font(.title3)
                                .offset(x: 6, y: -6)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .scaleEffect(isHovering && !isSelected ? 1.02 : 1)

                Text(title)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A miniature era window, used to preview layout options.
/// The element the option is about is drawn with the accent color.
struct BrowserLayoutMockup: View {
    enum Emphasis {
        case addressBar
        case none
    }

    var addressBar: UserPreferences.AddressBarPosition = .sidebarTop
    var loadingIndicator: UserPreferences.LoadingIndicatorPosition? = nil
    var background: UserPreferences.WindowBackgroundStyle = .thinMaterial
    var emphasis: Emphasis = .none

    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color { .accentColor }
    private var element: Color { .primary.opacity(0.16) }
    private var page: Color { colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.9) }

    var body: some View {
        HStack(spacing: 5) {
            sidebar
                .frame(width: 46)
            pageArea
        }
        .padding(5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            windowBackground
                .clipShape(.rect(cornerRadius: 9))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
        }
    }

    // MARK: - Parts

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2.5) {
                Circle().fill(.red.opacity(0.85))
                Circle().fill(.yellow.opacity(0.85))
                Circle().fill(.green.opacity(0.85))
            }
            .frame(width: 19, height: 5)

            if addressBar == .sidebarTop {
                addressPill
            }

            Capsule().fill(element).frame(width: 22, height: 3)
                .padding(.top, 2)

            ForEach(0..<3) { index in
                tabRow(isFirst: index == 0)
            }

            Spacer(minLength: 0)

            if addressBar == .sidebarBottom {
                addressPill
            }

            HStack(spacing: 3) {
                Circle().fill(element).frame(width: 5, height: 5)
                Spacer()
                Circle().fill(element).frame(width: 5, height: 5)
            }
        }
    }

    private var pageArea: some View {
        VStack(spacing: 4) {
            if addressBar == .abovePage {
                HStack(spacing: 3) {
                    Circle().fill(element).frame(width: 4, height: 4)
                    Circle().fill(element).frame(width: 4, height: 4)
                    addressPill
                        .frame(maxWidth: 58)
                        .frame(maxWidth: .infinity)
                }
            }

            RoundedRectangle(cornerRadius: 5)
                .fill(page)
                .overlay(alignment: .topLeading) {
                    if loadingIndicator == .onWebView {
                        Capsule()
                            .fill(accent)
                            .frame(height: 2)
                            .padding(.trailing, 36)
                    }
                }
                .overlay {
                    // Some "page content"
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(element).frame(width: 44, height: 4)
                        Capsule().fill(element).frame(width: 64, height: 3)
                        Capsule().fill(element).frame(width: 54, height: 3)
                    }
                    .opacity(0.7)
                }
        }
    }

    private var addressPill: some View {
        Capsule()
            .fill(emphasis == .addressBar ? accent : element)
            .frame(height: 8)
            .overlay(alignment: .bottomLeading) {
                if loadingIndicator == .onURL {
                    Capsule()
                        .fill(accent)
                        .frame(width: 22, height: 2)
                        .offset(y: 3)
                }
            }
    }

    private func tabRow(isFirst: Bool) -> some View {
        HStack(spacing: 3) {
            if isFirst && loadingIndicator == .onTab {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(accent, lineWidth: 1.5)
                    .frame(width: 5, height: 5)
            } else {
                RoundedRectangle(cornerRadius: 1.5).fill(.primary.opacity(0.3)).frame(width: 5, height: 5)
            }
            Capsule().fill(element).frame(height: 3)
        }
        .padding(.horizontal, 3)
        .frame(height: 9)
        .background(isFirst ? page : .clear, in: .rect(cornerRadius: 3))
    }

    @ViewBuilder
    private var windowBackground: some View {
        switch background {
        case .liquidGlass:
            LinearGradient(colors: [.blue.opacity(0.35), .purple.opacity(0.28), .teal.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(.white.opacity(colorScheme == .dark ? 0.05 : 0.25))
        case .thinMaterial:
            Color.gray.opacity(colorScheme == .dark ? 0.28 : 0.18)
        }
    }
}
