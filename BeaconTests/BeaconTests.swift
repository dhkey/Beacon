//
//  BeaconTests.swift
//  BeaconTests
//
//  Created by Denys Yazan on 22.08.2026.
//

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

}
