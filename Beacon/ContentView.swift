//
//  ContentView.swift
//  Beacon
//
//  Created by Denys Yazan on 22.08.2026.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(\.openSettings) private var openSettings
    @Bindable var model: LauncherModel
    @FocusState private var searchFocused: Bool
    @State private var lastPointerLocation: NSPoint?

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().opacity(0.65)
            results
            Divider().opacity(0.65)
            footer
        }
        .frame(width: 720, height: 500)
        .background(Color.beaconCanvas)
        .preferredColorScheme(.light)
        .task {
            model.onOpenSettings = {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            await focusSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .beaconDidShow)) { _ in
            Task { await focusSearch() }
        }
        .onExitCommand {
            model.dismiss()
        }
        .onKeyPress(.upArrow, phases: [.down, .repeat]) { keyPress in
            if keyPress.modifiers.contains(.option), model.canReorderFavoriteForSelection {
                model.moveFavoriteForSelection(by: -1)
                return .handled
            }
            model.moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow, phases: [.down, .repeat]) { keyPress in
            if keyPress.modifiers.contains(.option), model.canReorderFavoriteForSelection {
                model.moveFavoriteForSelection(by: 1)
                return .handled
            }
            model.moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.return) {
            guard model.isSettingsButtonSelected else { return .ignored }
            model.runSelected()
            return .handled
        }
        .onKeyPress("k", phases: .down) { keyPress in
            guard keyPress.modifiers.contains(.command) else { return .ignored }
            return model.toggleFavoriteForSelection() ? .handled : .ignored
        }
        .onChange(of: model.query) { _, _ in
            lastPointerLocation = NSEvent.mouseLocation
        }
    }

    private var searchBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.beaconInk)

            TextField("Search apps and commands", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(Color.beaconInk)
                .focused($searchFocused)
                .onSubmit { runCurrentSelection() }
                .accessibilityIdentifier("launcherSearchField")
        }
        .padding(.horizontal, 22)
        .frame(height: 72)
    }

    @ViewBuilder
    private var results: some View {
        if model.results.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: emptyStateSymbol)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.beaconMuted)
                    .symbolEffect(.rotate, isActive: model.isIndexing)
                Text(emptyStateTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.beaconMuted)
                if model.query.isEmpty && !model.isIndexing {
                    Text("Search for an app or command, then press ⌘K")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beaconMuted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                            ResultRow(
                                result: result,
                                isSelected: !model.isSettingsButtonSelected && index == model.selectedIndex,
                                isFavorite: model.isFavorite(result),
                                onPointerMove: { updateSelectionFromPointer(to: index) },
                                onRun: {
                                    model.selectResult(at: index)
                                    model.runSelected()
                                }
                            )
                            .id(result.id)
                            .accessibilityIdentifier(
                                result.id == LauncherModel.settingsResultID
                                    ? "openBeaconSettingsResult"
                                    : "launcherResult"
                            )
                        }
                    }
                    .padding(10)
                }
                .onChange(of: model.selectedIndex) { _, index in
                    guard model.results.indices.contains(index) else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(model.results[index].id, anchor: .center)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 18) {
            Label("Open", systemImage: "return")
            Label("Navigate", systemImage: "arrow.up.arrow.down")
            Label("Favorite ⌘K", systemImage: "star")
            Text("Hold ⌥ and press ↑↓ to rearrange")
            Spacer()
            Button {
                model.openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(model.isSettingsButtonSelected ? Color.beaconSelection : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("openSettingsButton")
            .accessibilityAddTraits(model.isSettingsButtonSelected ? .isSelected : [])
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Color.beaconMuted)
        .padding(.horizontal, 18)
        .frame(height: 38)
    }

    private func focusSearch() async {
        try? await Task.sleep(for: .milliseconds(80))
        searchFocused = true
    }

    private func runCurrentSelection() {
        model.runSelected()
    }

    private func updateSelectionFromPointer(to index: Int) {
        let pointerLocation = NSEvent.mouseLocation
        guard pointerLocation != lastPointerLocation else { return }
        lastPointerLocation = pointerLocation
        model.selectResult(at: index)
    }

    private var emptyStateSymbol: String {
        if model.isIndexing { return "arrow.trianglehead.2.clockwise.rotate.90" }
        return model.query.isEmpty ? "star" : "text.magnifyingglass"
    }

    private var emptyStateTitle: String {
        if model.isIndexing { return "Indexing applications" }
        return model.query.isEmpty ? "No favorites yet" : "No results for “\(model.query)”"
    }
}

private struct ResultRow: View {
    let result: LauncherResult
    let isSelected: Bool
    let isFavorite: Bool
    let onPointerMove: () -> Void
    let onRun: () -> Void

    var body: some View {
        Button(action: onRun) {
            HStack(spacing: 13) {
                ResultIcon(result: result)

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.beaconInk)
                        .lineLimit(1)
                    Text(result.subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.beaconMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beaconMuted)
                        .accessibilityLabel("Favorite")
                }

                if isSelected {
                    Text("↵")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.beaconMuted)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(Color.white.opacity(0.78))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black.opacity(0.07), lineWidth: 1)
                        }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 58)
            .contentShape(Rectangle())
            .background(isSelected ? Color.beaconSelection : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onContinuousHover { phase in
            if case .active = phase {
                onPointerMove()
            }
        }
    }
}

private struct ResultIcon: View {
    let result: LauncherResult

    var body: some View {
        Group {
            if let icon = result.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            } else {
                Image(systemName: result.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.beaconInk)
            }
        }
        .frame(width: 38, height: 38)
        .background(result.icon == nil ? result.tint : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

extension Color {
    static let beaconCanvas = Color(red: 0.973, green: 0.969, blue: 0.953)
    static let beaconInk = Color(red: 0.10, green: 0.10, blue: 0.095)
    static let beaconMuted = Color(red: 0.43, green: 0.42, blue: 0.39)
    static let beaconSelection = Color(red: 0.91, green: 0.925, blue: 0.90)
}

#Preview {
    ContentView(model: LauncherModel.preview)
}
