import AppKit
import Testing
@testable import LyricsXApp

@MainActor private final class TouchBarBridgeRecorder {
    enum Event: Equatable {
        case add(ObjectIdentifier)
        case remove(ObjectIdentifier)
        case presence(NSTouchBarItem.Identifier, Bool)
        case present(ObjectIdentifier, NSTouchBarItem.Identifier)
        case dismiss(ObjectIdentifier)
    }

    var events: [Event] = []
    var operations: TouchBarSystemBridge.Operations {
        .init(
            addItem: { self.events.append(.add(ObjectIdentifier($0))) },
            removeItem: { self.events.append(.remove(ObjectIdentifier($0))) },
            setPresence: { self.events.append(.presence($0, $1)) },
            present: { self.events.append(.present(ObjectIdentifier($0), $1)) },
            dismiss: { self.events.append(.dismiss(ObjectIdentifier($0))) }
        )
    }
}

@Suite @MainActor struct TouchBarSystemBridgeTests {
    @Test func unavailableSystemAPIsFailWithoutRegisteringAnItem() {
        let bridge = TouchBarSystemBridge(operations: nil)
        let item = NSCustomTouchBarItem(identifier: .init("com.lyricsx.test.unavailable"))
        let bar = NSTouchBar()
        #expect(!bridge.isAvailable)
        #expect(!bridge.install(item: item))
        #expect(!bridge.present(bar, itemIdentifier: item.identifier))
        bridge.dismiss(bar)
        bridge.remove(item: item)
        #expect(!bridge.present(bar, itemIdentifier: item.identifier))
    }

    @Test func registrationAndRemovalRespectObjectOwnership() {
        let recorder = TouchBarBridgeRecorder()
        let bridge = TouchBarSystemBridge(operations: recorder.operations)
        let item = NSCustomTouchBarItem(identifier: .init("com.lyricsx.test.owner"))
        let foreignItem = NSCustomTouchBarItem(identifier: item.identifier)
        let bar = NSTouchBar()

        #expect(bridge.isAvailable)
        #expect(!bridge.present(bar, itemIdentifier: item.identifier))
        #expect(bridge.install(item: item))
        #expect(bridge.install(item: item))
        #expect(!bridge.install(item: foreignItem))
        bridge.remove(item: foreignItem)
        #expect(recorder.events == [.add(ObjectIdentifier(item)), .presence(item.identifier, true)])

        #expect(bridge.present(bar, itemIdentifier: item.identifier))
        bridge.dismiss(NSTouchBar())
        bridge.remove(item: item)
        bridge.remove(item: item)
        bridge.dismiss(bar)
        #expect(recorder.events == [
            .add(ObjectIdentifier(item)), .presence(item.identifier, true),
            .present(ObjectIdentifier(bar), item.identifier), .dismiss(ObjectIdentifier(bar)),
            .presence(item.identifier, false), .remove(ObjectIdentifier(item)),
        ])
    }

    @Test func switchingBarsDismissesOnlyThePreviouslyPresentedBar() {
        let recorder = TouchBarBridgeRecorder()
        let bridge = TouchBarSystemBridge(operations: recorder.operations)
        let first = NSCustomTouchBarItem(identifier: .init("com.lyricsx.test.first"))
        let second = NSCustomTouchBarItem(identifier: .init("com.lyricsx.test.second"))
        let firstBar = NSTouchBar(), secondBar = NSTouchBar()
        #expect(bridge.install(item: first))
        #expect(bridge.install(item: second))
        #expect(bridge.present(firstBar, itemIdentifier: first.identifier))
        recorder.events.removeAll()

        #expect(bridge.present(secondBar, itemIdentifier: second.identifier))
        bridge.remove(item: first)
        bridge.dismiss(firstBar)
        #expect(recorder.events == [
            .dismiss(ObjectIdentifier(firstBar)), .present(ObjectIdentifier(secondBar), second.identifier),
            .presence(first.identifier, false), .remove(ObjectIdentifier(first)),
        ])
        bridge.remove(item: second)
        #expect(Array(recorder.events.suffix(3)) == [
            .dismiss(ObjectIdentifier(secondBar)), .presence(second.identifier, false), .remove(ObjectIdentifier(second)),
        ])
    }

    @Test func disabledOrSleepingItemCanBeRegisteredAgain() {
        let recorder = TouchBarBridgeRecorder()
        let bridge = TouchBarSystemBridge(operations: recorder.operations)
        let identifier = NSTouchBarItem.Identifier("com.lyricsx.test.recovery")
        let original = NSCustomTouchBarItem(identifier: identifier)
        let bar = NSTouchBar()
        #expect(bridge.install(item: original))
        #expect(bridge.present(bar, itemIdentifier: identifier))
        bridge.dismiss(bar)
        bridge.dismiss(bar)
        bridge.remove(item: original)
        #expect(!bridge.present(bar, itemIdentifier: identifier))
        recorder.events.removeAll()

        let replacement = NSCustomTouchBarItem(identifier: identifier)
        #expect(bridge.install(item: replacement))
        bridge.remove(item: original)
        #expect(bridge.present(bar, itemIdentifier: identifier))
        bridge.remove(item: replacement)
        #expect(recorder.events == [
            .add(ObjectIdentifier(replacement)), .presence(identifier, true),
            .present(ObjectIdentifier(bar), identifier), .dismiss(ObjectIdentifier(bar)),
            .presence(identifier, false), .remove(ObjectIdentifier(replacement)),
        ])
    }
}
