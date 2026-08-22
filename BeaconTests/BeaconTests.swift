//
//  BeaconTests.swift
//  BeaconTests
//
//  Created by Denys Yazan on 22.08.2026.
//

import Foundation
import Testing
@testable import Beacon

struct BeaconTests {

    @Test func normalizationIgnoresCaseWhitespaceAndDiacritics() {
        #expect(LauncherModel.normalized("  ČalCulator  ") == "calculator")
    }

    @Test func matchScoreRanksExactAndPrefixMatchesFirst() {
        let exact = LauncherModel.matchScore(query: "notes", candidate: "notes")
        let prefix = LauncherModel.matchScore(query: "notes", candidate: "notes application")
        let contains = LauncherModel.matchScore(query: "notes", candidate: "open notes application")

        #expect(exact != nil)
        #expect(prefix != nil)
        #expect(contains != nil)
        #expect(exact! > prefix!)
        #expect(prefix! > contains!)
    }

    @Test func fuzzyMatchAcceptsOrderedCharactersOnly() {
        #expect(LauncherModel.matchScore(query: "sset", candidate: "system settings") != nil)
        #expect(LauncherModel.matchScore(query: "zzz", candidate: "system settings") == nil)
    }
    @Test @MainActor func doubleModifierRequiresTwoQuickPresses() {
        var detector = DoubleModifierPressDetector()

        let firstPress = detector.flagsChanged(modifierIsPressed: true, hasOtherModifiers: false, timestamp: 1.0)
        let firstRelease = detector.flagsChanged(modifierIsPressed: false, hasOtherModifiers: false, timestamp: 1.1)
        let secondPress = detector.flagsChanged(modifierIsPressed: true, hasOtherModifiers: false, timestamp: 1.3)

        #expect(!firstPress)
        #expect(!firstRelease)
        #expect(secondPress)
    }

    @Test @MainActor func doubleModifierRejectsSlowOrModifiedPresses() {
        var detector = DoubleModifierPressDetector()

        let firstPress = detector.flagsChanged(modifierIsPressed: true, hasOtherModifiers: false, timestamp: 1.0)
        let firstRelease = detector.flagsChanged(modifierIsPressed: false, hasOtherModifiers: false, timestamp: 1.1)
        let slowPress = detector.flagsChanged(modifierIsPressed: true, hasOtherModifiers: false, timestamp: 1.5)
        let slowRelease = detector.flagsChanged(modifierIsPressed: false, hasOtherModifiers: false, timestamp: 1.6)
        let modifiedPress = detector.flagsChanged(modifierIsPressed: true, hasOtherModifiers: true, timestamp: 1.7)

        #expect(!firstPress)
        #expect(!firstRelease)
        #expect(!slowPress)
        #expect(!slowRelease)
        #expect(!modifiedPress)
    }

    @Test @MainActor func doubleModifierShortcutPersists() {
        let suiteName = "BeaconTests.doubleModifierShortcutPersists"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let model = LauncherModel(defaults: defaults)
        model.updateShortcut(KeyboardShortcut.doubleTap(.command))
        let restoredModel = LauncherModel(defaults: defaults)

        #expect(restoredModel.shortcut == KeyboardShortcut.doubleTap(.command))
        #expect(restoredModel.shortcut.keyCapComponents == ["⌘", "⌘"])
    }
}
