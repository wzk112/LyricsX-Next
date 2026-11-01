import AppKit
import Darwin
import ObjectiveC

/// Optional access to the system Touch Bar. Callers own the user's opt-in and
/// must remove their item when disabling the feature or stopping the app.
/// Public, foreground NSTouchBar support does not depend on this bridge.
@MainActor final class TouchBarSystemBridge {
    struct Operations {
        var addItem: (NSCustomTouchBarItem) -> Void
        var removeItem: (NSCustomTouchBarItem) -> Void
        var setPresence: (NSTouchBarItem.Identifier, Bool) -> Void
        var present: (NSTouchBar, NSTouchBarItem.Identifier) -> Void
        var dismiss: (NSTouchBar) -> Void
    }

    private let operations: Operations?
    private var installedItems: [NSTouchBarItem.Identifier: NSCustomTouchBarItem] = [:]
    private var presentedBar: NSTouchBar?
    private var presentedIdentifier: NSTouchBarItem.Identifier?

    /// Describes API availability, not the presence of physical Touch Bar hardware.
    var isAvailable: Bool { operations != nil }

    init() { operations = Runtime.operations() }

    /// Allows lifecycle tests to exercise ownership without changing the system bar.
    init(operations: Operations?) { self.operations = operations }

    @discardableResult
    func install(item: NSCustomTouchBarItem) -> Bool {
        guard let operations else { return false }
        if let installed = installedItems[item.identifier] { return installed === item }
        operations.addItem(item)
        operations.setPresence(item.identifier, true)
        installedItems[item.identifier] = item
        return true
    }

    func remove(item: NSCustomTouchBarItem) {
        guard let operations, installedItems[item.identifier] === item else { return }
        if presentedIdentifier == item.identifier, let bar = presentedBar { dismiss(bar) }
        operations.setPresence(item.identifier, false)
        operations.removeItem(item)
        installedItems[item.identifier] = nil
    }

    /// A true result means the request was dispatched; system policy and available
    /// hardware still decide whether the bar is shown. It is not display validation.
    @discardableResult
    func present(_ touchBar: NSTouchBar, itemIdentifier: NSTouchBarItem.Identifier) -> Bool {
        guard let operations, installedItems[itemIdentifier] != nil else { return false }
        if let previous = presentedBar, previous !== touchBar { dismiss(previous) }
        operations.present(touchBar, itemIdentifier)
        presentedBar = touchBar
        presentedIdentifier = itemIdentifier
        return true
    }

    func dismiss(_ touchBar: NSTouchBar) {
        guard let operations, presentedBar === touchBar else { return }
        operations.dismiss(touchBar)
        presentedBar = nil
        presentedIdentifier = nil
    }

    @MainActor private enum Runtime {
        // Keep the framework loaded while its function pointer may be called.
        // Nothing is enabled, presented or globally configured by loading it.
        static let framework = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_LAZY | RTLD_LOCAL)

        typealias ItemAction = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        typealias PresentAction = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Void
        // Objective-C BOOL is signed char on Intel and bool on Apple Silicon.
        // ObjCBool preserves that ABI instead of assuming Swift Bool on both.
        typealias PresenceAction = @convention(c) (NSString, ObjCBool) -> Void

        static func operations() -> Operations? {
            // Signatures are checked before casting IMPs. This is deliberately
            // optional: disappearance or signature changes disable background UI.
            let addSelector = NSSelectorFromString("addSystemTrayItem:")
            let removeSelector = NSSelectorFromString("removeSystemTrayItem:")
            let presentSelector = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
            let dismissSelector = NSSelectorFromString("dismissSystemModalTouchBar:")
            guard let framework,
                  let presenceSymbol = dlsym(framework, "DFRElementSetControlStripPresenceForIdentifier"),
                  let addMethod = checkedClassMethod(NSTouchBarItem.self, selector: addSelector, objects: 1),
                  let removeMethod = checkedClassMethod(NSTouchBarItem.self, selector: removeSelector, objects: 1),
                  let presentMethod = checkedClassMethod(NSTouchBar.self, selector: presentSelector, objects: 2),
                  let dismissMethod = checkedClassMethod(NSTouchBar.self, selector: dismissSelector, objects: 1) else { return nil }

            // ABI declarations are based on the existing legacy dependency:
            // ddddxxx/TouchBarHelper @ 003d41193ac1c6ab9cc570a1923587298014bf1d,
            // Sources/DFRPrivate/include/DFRPrivateHeader.h. No close-box setting,
            // placement override, simulator activation or global strip setting is used.
            let add = unsafeBitCast(method_getImplementation(addMethod), to: ItemAction.self)
            let remove = unsafeBitCast(method_getImplementation(removeMethod), to: ItemAction.self)
            let present = unsafeBitCast(method_getImplementation(presentMethod), to: PresentAction.self)
            let dismiss = unsafeBitCast(method_getImplementation(dismissMethod), to: ItemAction.self)
            let presence = unsafeBitCast(presenceSymbol, to: PresenceAction.self)
            return Operations(
                addItem: { add(NSTouchBarItem.self, addSelector, $0) },
                removeItem: { remove(NSTouchBarItem.self, removeSelector, $0) },
                setPresence: { presence($0.rawValue as NSString, ObjCBool($1)) },
                present: { present(NSTouchBar.self, presentSelector, $0, $1.rawValue as NSString) },
                dismiss: { dismiss(NSTouchBar.self, dismissSelector, $0) }
            )
        }

        private static func checkedClassMethod(_ type: AnyClass, selector: Selector, objects: UInt32) -> Method? {
            guard let method = class_getClassMethod(type, selector),
                  method_getNumberOfArguments(method) == objects + 2 else { return nil }
            let returnType = method_copyReturnType(method)
            defer { free(returnType) }
            guard String(cString: returnType) == "v" else { return nil }
            for index in 2 ..< objects + 2 {
                guard let argument = method_copyArgumentType(method, index) else { return nil }
                let isObject = argument.pointee == 64 // '@', including typed objects.
                free(argument)
                guard isObject else { return nil }
            }
            return method
        }
    }
}
