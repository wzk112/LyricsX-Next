import Foundation
import SwiftUI
import Testing
@testable import LyricsXApp

@MainActor struct MainLyricPositionTests {
    @Test func existingUsersStayCenteredAndUpperPositionPersists() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.mainLyricPosition == .center)
        let overlayWidth = preferences.overlayWidth
        let overlayMode = preferences.overlaySecondaryMode
        preferences.mainLyricPosition = .upper
        #expect(defaults.string(forKey: "mainLyricPosition") == "upper")
        let restored = Preferences(defaults: defaults)
        #expect(restored.mainLyricPosition == .upper)
        #expect(restored.overlayWidth == overlayWidth && restored.overlaySecondaryMode == overlayMode)
        defaults.set("unknown", forKey: "mainLyricPosition")
        #expect(Preferences(defaults: defaults).mainLyricPosition == .center)
    }

    @Test func bothEndsCanReachTheirAnchorForShortAndMultilineRows() {
        let placements = [MainLyricPosition.center.placement(), MainLyricPosition.upper.placement()]
            + [5.0, 12, 30, 50, 80, 95].map { MainLyricPosition.custom.placement(customPercent: $0) }
        for placement in placements {
            #expect(abs(placement.anchor.y - placement.fraction) < 0.000001)
            for viewport in [160.0, 480, 900] {
                let insets = placement.insets(viewportHeight: viewport)
                for heights in [[28.0], [28, 130, 65], [180, 35, 220, 60], [1200.0]] {
                    let spacing = 26.0
                    let contentHeight = insets.top + heights.reduce(0, +)
                        + Double(heights.count - 1) * spacing + insets.bottom
                    let maximumOffset = max(0, contentHeight - viewport)
                    var rowStart = insets.top
                    for height in heights {
                        let destination = rowStart - (viewport - height) * placement.fraction
                        #expect(destination >= 0 && destination <= maximumOffset + 0.0001)
                        let rowAnchor = rowStart + height * placement.fraction - destination
                        #expect(abs(rowAnchor - viewport * placement.fraction) < 0.0001)
                        rowStart += height + spacing
                    }
                }
            }
        }
        #expect(MainLyricPosition.upper.placement().fraction < MainLyricPosition.center.placement().fraction)
        #expect(MainLyricPosition.upper.placement().insets(viewportHeight: -.infinity).top == 0)
    }

    @Test func customPercentPersistsAndPresetSwitchesKeepItsValue() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.mainLyricCustomPercent == 30)
        preferences.mainLyricCustomPercent = 12
        preferences.mainLyricPosition = .custom
        #expect(preferences.mainLyricPlacement.fraction == 0.12)
        let restored = Preferences(defaults: defaults)
        #expect(restored.mainLyricPosition == .custom && restored.mainLyricCustomPercent == 12)
        preferences.mainLyricPosition = .upper
        #expect(preferences.mainLyricPlacement.fraction == 0.3)
        preferences.mainLyricPosition = .center
        #expect(preferences.mainLyricPlacement.fraction == 0.5)
        preferences.mainLyricPosition = .custom
        #expect(preferences.mainLyricPlacement.fraction == 0.12)
        #expect(defaults.double(forKey: "mainLyricCustomPercent") == 12)
    }

    @Test func corruptCustomValuesCannotCreateInvalidScrollGeometry() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let cases: [(Double, Double)] = [(-200, 5), (500, 95), (12.7, 13), (.nan, 30), (.infinity, 30), (-.infinity, 30)]
        for (value, expected) in cases {
            defaults.set(value, forKey: "mainLyricCustomPercent")
            let preferences = Preferences(defaults: defaults)
            #expect(preferences.mainLyricCustomPercent == expected)
            preferences.mainLyricCustomPercent = 45
            preferences.mainLyricCustomPercent = value
            #expect(preferences.mainLyricCustomPercent == expected)
            #expect(defaults.double(forKey: "mainLyricCustomPercent") == expected)
            preferences.mainLyricPosition = .custom
            #expect(preferences.mainLyricPlacement.fraction.isFinite)
        }
    }

    @Test func edgeFadesLeaveRoomForCustomCurrentRows() {
        for percentage in [5.0, 12, 30, 50, 80, 95] {
            let placement = MainLyricPosition.custom.placement(customPercent: percentage)
            #expect(placement.topFadeEnd < placement.fraction)
            #expect(placement.bottomFadeStart > placement.fraction)
            // Short rows fit between the edge fades even at the endpoints.
            let viewport = 480.0, rowHeight = 80.0
            let start = (viewport - rowHeight) * placement.fraction
            #expect(start >= viewport * placement.topFadeEnd)
            #expect(start + rowHeight <= viewport * placement.bottomFadeStart)
        }
    }

    private func input(index: Int? = 5, browsing: Bool = false, reduced: Bool = false,
                       viewport: CGSize = .init(width: 500, height: 480),
                       placement: MainLyricPosition = .center, showTranslation: Bool = true,
                       fontSize: Double = 30, customPercent: Double = 30) -> MainLyricFollowInput {
        .init(index: index, browsing: browsing, reduced: reduced,
              layout: .init(viewport: viewport, position: placement.placement(customPercent: customPercent), primaryFontSize: fontSize,
                            translationFontSize: 14, showTranslation: showTranslation,
                            fontName: "", conversion: "原文"))
    }

    @Test func layoutChangesRetargetImmediatelyWhileBrowsingKeepsItsPosition() throws {
        let previous = input()
        let layouts = [input(placement: .upper), input(viewport: .init(width: 320, height: 250)),
                       input(showTranslation: false), input(fontSize: 42), input(reduced: true)]
        for current in layouts {
            let policy = try #require(current.policy(comparedTo: previous))
            #expect(policy.force && !policy.animated)
            let browsing = MainLyricFollowInput(index: current.index, browsing: true,
                                                reduced: current.reduced, layout: current.layout)
            #expect(browsing.policy(comparedTo: previous)?.force == nil)
        }
        let returned = try #require(input(placement: .upper).policy(comparedTo: input(browsing: true, placement: .upper)))
        #expect(returned.force && returned.animated && returned.returning)
        let cue = try #require(input(index: 6).policy(comparedTo: previous))
        #expect(!cue.force && cue.animated)
        let reducedCue = try #require(input(index: 6, reduced: true).policy(comparedTo: input(reduced: true)))
        #expect(!reducedCue.force && !reducedCue.animated)
    }

    @Test func changingOnlyCustomPercentRetargetsWhileReturningStillAnimates() throws {
        let original = input(placement: .custom, customPercent: 12)
        let changed = input(placement: .custom, customPercent: 20)
        let policy = try #require(changed.policy(comparedTo: original))
        #expect(policy.force && !policy.animated)
        let same = input(placement: .custom, customPercent: 12)
        #expect(same.layout == original.layout)
        let returning = try #require(same.policy(comparedTo: input(browsing: true, placement: .custom, customPercent: 12)))
        #expect(returning.force && returning.animated && returning.returning)
    }
}
