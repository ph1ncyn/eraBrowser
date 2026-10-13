//
//  SplitView.swift
//  Browser
//
//  Created by ph1ncyn on 10/13/26.
//

import SwiftUI

/// How the tabs of a split view are arranged
enum SplitLayoutStyle: String, CaseIterable, Identifiable {
    case columns
    case rows
    case grid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .columns: return "Side by Side"
        case .rows: return "Stacked"
        case .grid: return "Grid"
        }
    }

    var systemImage: String {
        switch self {
        case .columns: return "rectangle.split.3x1"
        case .rows: return "rectangle.split.1x2"
        case .grid: return "rectangle.split.2x2"
        }
    }

    var next: SplitLayoutStyle {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// Tabs of a space shown together. Visible whenever the space's current tab is one of them.
struct SplitGroup: Equatable {
    var tabIDs: [UUID]
    var layout: SplitLayoutStyle = .columns
}

/// Places the visible tabs of a split view in a grid and keeps the other tabs full size behind them.
/// All the web views stay in the same container, so entering or leaving the split never reloads a page.
struct SplitViewLayout: Layout {
    var visibleIDs: [UUID]
    var style: SplitLayoutStyle
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = Self.frames(count: visibleIDs.count, style: style, in: bounds, spacing: spacing)
        for subview in subviews {
            let id = subview[SplitTabIDKey.self]
            if let id, let index = visibleIDs.firstIndex(of: id), index < frames.count {
                subview.place(at: frames[index].origin, proposal: ProposedViewSize(frames[index].size))
            } else {
                subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            }
        }
    }

    /// Frames of `count` panes in `bounds`
    static func frames(count: Int, style: SplitLayoutStyle, in bounds: CGRect, spacing: CGFloat) -> [CGRect] {
        guard count > 1 else { return [bounds] }

        switch style {
        case .columns:
            let width = (bounds.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            return (0..<count).map { index in
                CGRect(x: bounds.minX + CGFloat(index) * (width + spacing), y: bounds.minY, width: width, height: bounds.height)
            }
        case .rows:
            let height = (bounds.height - spacing * CGFloat(count - 1)) / CGFloat(count)
            return (0..<count).map { index in
                CGRect(x: bounds.minX, y: bounds.minY + CGFloat(index) * (height + spacing), width: bounds.width, height: height)
            }
        case .grid:
            let columns = Int(Double(count).squareRoot().rounded(.up))
            let rows = Int((Double(count) / Double(columns)).rounded(.up))
            let height = (bounds.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            var frames: [CGRect] = []
            for row in 0..<rows {
                // The last row stretches its panes when it has fewer of them (e.g. 3 tabs: 2 on top, 1 below)
                let panesInRow = min(columns, count - row * columns)
                let width = (bounds.width - spacing * CGFloat(panesInRow - 1)) / CGFloat(panesInRow)
                for column in 0..<panesInRow {
                    frames.append(CGRect(
                        x: bounds.minX + CGFloat(column) * (width + spacing),
                        y: bounds.minY + CGFloat(row) * (height + spacing),
                        width: width,
                        height: height
                    ))
                }
            }
            return frames
        }
    }
}

/// Identifies the tab of a subview of `SplitViewLayout`
struct SplitTabIDKey: LayoutValueKey {
    static let defaultValue: UUID? = nil
}

// MARK: - Split view state
extension BrowserWindowState {
    static let maxSplitTabs = 4

    /// Tabs of the space's split view (empty if there is no split with at least 2 open tabs)
    func splitTabs(in space: BrowserSpace) -> [BrowserTab] {
        guard let group = splitGroups[space.id] else { return [] }
        let allTabs = space.allTabs
        let tabs = group.tabIDs.compactMap { id in allTabs.first(where: { $0.id == id }) }
        return tabs.count > 1 ? tabs : []
    }

    /// Tabs shown in the space: its split view when the current tab is part of it, otherwise the current tab
    func visibleTabs(in space: BrowserSpace) -> [BrowserTab] {
        guard let currentTab = space.currentTab else { return [] }
        let split = splitTabs(in: space)
        return split.contains(currentTab) ? split : [currentTab]
    }

    func isShowingSplit(in space: BrowserSpace) -> Bool {
        visibleTabs(in: space).count > 1
    }

    func splitLayout(in space: BrowserSpace) -> SplitLayoutStyle {
        splitGroups[space.id]?.layout ?? .columns
    }

    func isInSplit(_ tab: BrowserTab, in space: BrowserSpace) -> Bool {
        splitTabs(in: space).contains(tab)
    }

    /// Shows a tab next to the current tab: adds it to the current split view,
    /// or starts a new one with the current tab when the current tab isn't in a split
    func addToSplit(_ tab: BrowserTab, in space: BrowserSpace) {
        var ids = splitTabs(in: space).map(\.id)
        if let currentTab = space.currentTab, currentTab != tab, !ids.contains(currentTab.id) {
            ids = [currentTab.id]
        }
        guard !ids.contains(tab.id) else { return }
        guard ids.count < Self.maxSplitTabs else {
            presentActionAlert(message: "Split View Shows Up To \(Self.maxSplitTabs) Tabs", systemImage: "rectangle.split.2x2")
            return
        }
        ids.append(tab.id)
        guard ids.count > 1 else { return }

        tab.isSuspended = false
        withAnimation(.browserDefault) {
            splitGroups[space.id] = SplitGroup(tabIDs: ids, layout: splitLayout(in: space))
            space.currentTab = tab
        }
    }

    func removeFromSplit(_ tab: BrowserTab, in space: BrowserSpace) {
        guard var group = splitGroups[space.id] else { return }
        withAnimation(.browserDefault) {
            group.tabIDs.removeAll { $0 == tab.id }
            splitGroups[space.id] = group.tabIDs.count > 1 ? group : nil
        }
    }

    func closeSplit(in space: BrowserSpace) {
        withAnimation(.browserDefault) {
            splitGroups[space.id] = nil
        }
    }

    func setSplitLayout(_ layout: SplitLayoutStyle, in space: BrowserSpace) {
        guard splitGroups[space.id] != nil else { return }
        withAnimation(.browserDefault) {
            splitGroups[space.id]?.layout = layout
        }
    }

    /// Splits the current tab with the tab below it (or above it if it is the last one)
    func splitCurrentTabWithNext() {
        guard let space = currentSpace, let currentTab = space.currentTab else { return }
        let tabs = space.allTabs.filter { $0.type == .web }
        let split = isInSplit(currentTab, in: space) ? splitTabs(in: space) : []
        let candidates = tabs.filter { $0 != currentTab && !split.contains($0) }
        let index = tabs.firstIndex(of: currentTab) ?? 0
        guard let next = candidates.first(where: { (tabs.firstIndex(of: $0) ?? 0) > index }) ?? candidates.last else {
            presentActionAlert(message: "Open Another Tab To Use Split View", systemImage: "rectangle.split.2x1")
            return
        }
        addToSplit(next, in: space)
        // Keep the focus on the tab the user was on
        space.currentTab = currentTab
    }
}
