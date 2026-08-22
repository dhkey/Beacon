//
//  ContentView.swift
//  Beacon
//
//  Created by Denys Yazan on 22.08.2026.
//

import SwiftUI

struct ContentView: View {
    @Bindable var model: LauncherModel
    @FocusState private var searchFocused: Bool

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
            await focusSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .beaconDidShow)) { _ in
            Task { await focusSearch() }
        }
        .onExitCommand {
            model.dismiss()
        }
        .onKeyPress(.upArrow) {
            model.moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            model.moveSelection(by: 1)
            return .handled
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
                .onSubmit { model.runSelected() }
                .accessibilityIdentifier("launcherSearchField")

            ShortcutBadge(shortcut: model.shortcut)
        }
        .padding(.horizontal, 22)
        .frame(height: 72)
    }

    @ViewBuilder
    private var results: some View {
        if model.query.isEmpty {
            VStack(spacing: 0) {
                SettingsLink {
                    HStack(spacing: 13) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.beaconInk)
                            .frame(width: 38, height: 38)
                            .background(Color(red: 0.94, green: 0.91, blue: 0.88))
                            .clipShape(RoundedRectangle(cornerRadius: 9))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Open Beacon Settings")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.beaconInk)
                            Text("Shortcut and launcher preferences")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.beaconMuted)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 58)
                    .contentShape(Rectangle())
                    .background(Color.beaconSelection)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("openBeaconSettingsResult")
                .simultaneousGesture(TapGesture().onEnded {
                    model.dismiss()
                })

                Spacer()
            }
            .padding(10)
        } else if model.results.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: model.isIndexing ? "arrow.trianglehead.2.clockwise.rotate.90" : "text.magnifyingglass")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.beaconMuted)
                    .symbolEffect(.rotate, isActive: model.isIndexing)
                Text(model.isIndexing ? "Indexing applications" : "No results for “\(model.query)”")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.beaconMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                            ResultRow(
                                result: result,
                                isSelected: index == model.selectedIndex,
                                onHover: { hovering in
                                    if hovering { model.selectedIndex = index }
                                },
                                onRun: {
                                    model.selectedIndex = index
                                    model.runSelected()
                                }
                            )
                            .id(result.id)
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
            Spacer()
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("openSettingsButton")
            .simultaneousGesture(TapGesture().onEnded {
                model.dismiss()
            })
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
}

private struct ResultRow: View {
    let result: LauncherResult
    let isSelected: Bool
    let onHover: (Bool) -> Void
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
        .onHover(perform: onHover)
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

struct ShortcutBadge: View {
    let shortcut: KeyboardShortcut

    var body: some View {
        HStack(spacing: 3) {
            ForEach(shortcut.keyCapComponents, id: \.self) { key in
                Text(key)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.beaconMuted)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(Color.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.black.opacity(0.07), lineWidth: 1)
                    }
            }
        }
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
