import AppKit
import Observation
import SwiftUI

struct IndexedApplication: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let icon: NSImage

    init(url: URL) {
        self.url = url
        name = url.deletingPathExtension().lastPathComponent
        id = url.standardizedFileURL.path
        icon = NSWorkspace.shared.icon(forFile: url.path)
    }

    static func == (lhs: IndexedApplication, rhs: IndexedApplication) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum LauncherTarget: Hashable {
    case application(URL)
    case settings
    case url(URL)
}

struct LauncherResult: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let tint: Color
    let icon: NSImage?
    let target: LauncherTarget

    static func == (lhs: LauncherResult, rhs: LauncherResult) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
@Observable
final class LauncherModel {
    static let settingsResultID = "command:settings"

    var query = "" {
        didSet {
            selectedIndex = 0
            rebuildResults()
        }
    }
    var results: [LauncherResult] = []
    var selectedIndex = 0
    var isIndexing = false
    var shortcutRegistrationError: String?
    private(set) var favoriteIDs: [String]

    var onDismiss: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onShortcutChanged: ((KeyboardShortcut) -> Void)?

    var shortcut: KeyboardShortcut {
        didSet {
            defaults.set(shortcut.kind.rawValue, forKey: Keys.shortcutKind)
            defaults.set(Int(shortcut.keyCode), forKey: Keys.keyCode)
            defaults.set(Int(shortcut.modifiers), forKey: Keys.modifiers)
            onShortcutChanged?(shortcut)
        }
    }

    private var applications: [IndexedApplication] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let savedFavoriteIDs = defaults.stringArray(forKey: Keys.favoriteIDs) {
            favoriteIDs = Self.unique(savedFavoriteIDs)
        } else {
            favoriteIDs = [Self.settingsResultID]
        }
        if defaults.object(forKey: Keys.keyCode) != nil {
            shortcut = KeyboardShortcut(
                kind: KeyboardShortcut.Kind(rawValue: defaults.integer(forKey: Keys.shortcutKind)) ?? .keyCombination,
                keyCode: UInt32(defaults.integer(forKey: Keys.keyCode)),
                modifiers: UInt32(defaults.integer(forKey: Keys.modifiers))
            )
        } else {
            shortcut = .default
        }
        rebuildResults()
    }

    func prepareForPresentation() {
        query = ""
        selectedIndex = 0
    }

    func loadApplications() {
        updateApplications(onlyWhenNew: false)
    }

    func checkForNewApplications() {
        updateApplications(onlyWhenNew: true)
    }

    private func updateApplications(onlyWhenNew: Bool) {
        guard !isIndexing else { return }
        isIndexing = true
        let indexedPaths = Set(applications.map(\.id))

        Task {
            let urls = await Task.detached(priority: .utility) {
                Self.discoverApplicationURLs()
            }.value
            if !onlyWhenNew || Self.containsNewApplication(in: urls, indexedPaths: indexedPaths) {
                applications = urls.map(IndexedApplication.init)
                rebuildResults()
            }
            isIndexing = false
        }
    }

    func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + offset, 0), results.count - 1)
    }

    func runSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        run(results[selectedIndex])
    }

    func run(_ result: LauncherResult) {
        switch result.target {
        case .application(let url):
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        case .settings:
            dismiss()
            onOpenSettings?()
            return
        case .url(let url):
            NSWorkspace.shared.open(url)
        }
        dismiss()
    }

    func isFavorite(_ result: LauncherResult) -> Bool {
        favoriteIDs.contains(result.id)
    }

    @discardableResult
    func toggleFavoriteForSelection() -> Bool {
        guard results.indices.contains(selectedIndex) else { return false }
        let result = results[selectedIndex]
        guard result.id != "command:web-search" else { return false }

        if let index = favoriteIDs.firstIndex(of: result.id) {
            favoriteIDs.remove(at: index)
        } else {
            favoriteIDs.append(result.id)
        }
        defaults.set(favoriteIDs, forKey: Keys.favoriteIDs)

        if Self.normalized(query).isEmpty {
            rebuildResults()
        }
        return true
    }

    func dismiss() {
        onDismiss?()
    }

    func updateShortcut(_ shortcut: KeyboardShortcut) {
        self.shortcut = shortcut
    }

    func resetShortcut() {
        shortcut = .default
    }

    private func rebuildResults() {
        let normalizedQuery = Self.normalized(query)
        var candidates = commandResults()
        candidates.append(contentsOf: applications.map { app in
            LauncherResult(
                id: "app:\(app.id)",
                title: app.name,
                subtitle: "Application",
                symbolName: "app",
                tint: Color(red: 0.90, green: 0.93, blue: 0.96),
                icon: app.icon,
                target: .application(app.url)
            )
        })

        if normalizedQuery.isEmpty {
            let candidatesByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
            results = favoriteIDs.compactMap { candidatesByID[$0] }
        } else {
            results = candidates.compactMap { candidate -> (LauncherResult, Int)? in
                guard let score = Self.matchScore(query: normalizedQuery, candidate: Self.normalized(candidate.title + " " + candidate.subtitle)) else {
                    return nil
                }
                return (candidate, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 { return lhs.0.title.localizedStandardCompare(rhs.0.title) == .orderedAscending }
                return lhs.1 > rhs.1
            }
            .prefix(30)
            .map(\.0)

            if let webURL = Self.webSearchURL(for: query) {
                results.append(
                    LauncherResult(
                        id: "command:web-search",
                        title: "Search the web for “\(query)”",
                        subtitle: "Open in the default browser",
                        symbolName: "globe",
                        tint: Color(red: 0.90, green: 0.94, blue: 0.92),
                        icon: nil,
                        target: .url(webURL)
                    )
                )
            }
        }
        selectedIndex = results.isEmpty ? 0 : min(selectedIndex, results.count - 1)
    }

    private func commandResults() -> [LauncherResult] {
        return [
            LauncherResult(
                id: Self.settingsResultID,
                title: "Beacon Settings",
                subtitle: "Shortcut and launcher preferences",
                symbolName: "gearshape.fill",
                tint: Color(red: 0.94, green: 0.91, blue: 0.88),
                icon: nil,
                target: .settings
            ),
            LauncherResult(
                id: "command:applications",
                title: "Applications",
                subtitle: "Open folder in Finder",
                symbolName: "square.grid.2x2.fill",
                tint: Color(red: 0.95, green: 0.92, blue: 0.88),
                icon: nil,
                target: .url(URL(filePath: "/Applications"))
            )
        ]
    }

    nonisolated static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    nonisolated static func matchScore(query: String, candidate: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        if candidate == query { return 1_000 }
        if candidate.hasPrefix(query) { return 800 - candidate.count }
        if let range = candidate.range(of: query) {
            return 600 - candidate.distance(from: candidate.startIndex, to: range.lowerBound)
        }

        var queryIndex = query.startIndex
        var score = 0
        var lastMatch: String.Index?
        for index in candidate.indices where queryIndex < query.endIndex {
            if candidate[index] == query[queryIndex] {
                score += lastMatch.map { candidate.index(after: $0) == index ? 16 : 5 } ?? 5
                lastMatch = index
                query.formIndex(after: &queryIndex)
            }
        }
        return queryIndex == query.endIndex ? score : nil
    }

    nonisolated static func containsNewApplication(in urls: [URL], indexedPaths: Set<String>) -> Bool {
        urls.contains { !indexedPaths.contains($0.standardizedFileURL.path) }
    }

    nonisolated private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    nonisolated private static func discoverApplicationURLs() -> [URL] {
        let roots = [
            URL(filePath: "/Applications", directoryHint: .isDirectory),
            URL(filePath: "/System/Applications", directoryHint: .isDirectory),
            FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications", directoryHint: .isDirectory)
        ]
        let keys: [URLResourceKey] = [.isApplicationKey, .isDirectoryKey]
        var found: [String: URL] = [:]

        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension.caseInsensitiveCompare("app") == .orderedSame else { continue }
                found[url.standardizedFileURL.path] = url
            }
        }
        return found.values.sorted {
            $0.deletingPathExtension().lastPathComponent.localizedStandardCompare(
                $1.deletingPathExtension().lastPathComponent
            ) == .orderedAscending
        }
    }

    nonisolated private static func webSearchURL(for query: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }

    private enum Keys {
        static let shortcutKind = "launcherShortcutKind"
        static let keyCode = "launcherShortcutKeyCode"
        static let modifiers = "launcherShortcutModifiers"
        static let favoriteIDs = "launcherFavoriteIDs"
    }
}

extension LauncherModel {
    static var preview: LauncherModel {
        let model = LauncherModel(defaults: UserDefaults(suiteName: "BeaconPreview")!)
        return model
    }
}
