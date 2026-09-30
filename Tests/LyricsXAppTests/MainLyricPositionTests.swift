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
        for placement in MainLyricPosition.allCases {
            #expect(abs(placement.anchor.y - placement.fraction) < 0.000001)
            for viewport in [160.0, 480, 900] {
                let insets = placement.insets(viewportHeight: viewport)
                for heights in [[28.0], [28, 130, 65], [180, 35, 220, 60]] {
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
        #expect(MainLyricPosition.upper.fraction < MainLyricPosition.center.fraction)
        #expect(MainLyricPosition.upper.insets(viewportHeight: -.infinity).top == 0)
    }

    private func input(index: Int? = 5, browsing: Bool = false, reduced: Bool = false,
                       viewport: CGSize = .init(width: 500, height: 480),
                       placement: MainLyricPosition = .center, showTranslation: Bool = true,
                       fontSize: Double = 30) -> MainLyricFollowInput {
        .init(index: index, browsing: browsing, reduced: reduced,
              layout: .init(viewport: viewport, position: placement, primaryFontSize: fontSize,
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
}
