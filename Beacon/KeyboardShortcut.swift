import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

struct KeyboardShortcut: Equatable, Sendable {
    enum Kind: Int, Sendable {
        case keyCombination
        case doubleOption
        case doubleCommand
        case doubleControl
        case doubleShift
    }

    enum DoubleTapModifier: CaseIterable, Hashable, Sendable {
        case option
        case command
        case control
        case shift

        var eventFlag: NSEvent.ModifierFlags {
            switch self {
            case .option: .option
            case .command: .command
            case .control: .control
            case .shift: .shift
            }
        }

        var cgEventFlag: CGEventFlags {
            switch self {
            case .option: .maskAlternate
            case .command: .maskCommand
            case .control: .maskControl
            case .shift: .maskShift
            }
        }

        var glyph: String {
            switch self {
            case .option: "⌥"
            case .command: "⌘"
            case .control: "⌃"
            case .shift: "⇧"
            }
        }
    }

    var kind: Kind
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = KeyboardShortcut(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey)
    )
    static let doubleOption = doubleTap(.option)

    var doubleTapModifier: DoubleTapModifier? {
        switch kind {
        case .keyCombination: nil
        case .doubleOption: .option
        case .doubleCommand: .command
        case .doubleControl: .control
        case .doubleShift: .shift
        }
    }

    var keyCapComponents: [String] {
        if let doubleTapModifier {
            return [doubleTapModifier.glyph, doubleTapModifier.glyph]
        }

        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts
    }

    var displayName: String {
        keyCapComponents.joined()
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        kind = .keyCombination
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(kind: Kind, keyCode: UInt32, modifiers: UInt32) {
        self.kind = kind
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(event: NSEvent) {
        kind = .keyCombination
        keyCode = UInt32(event.keyCode)
        modifiers = Self.carbonModifiers(from: event.modifierFlags)
    }

    static func doubleTap(_ modifier: DoubleTapModifier) -> KeyboardShortcut {
        switch modifier {
        case .option:
            KeyboardShortcut(kind: .doubleOption, keyCode: UInt32(kVK_Option), modifiers: UInt32(optionKey))
        case .command:
            KeyboardShortcut(kind: .doubleCommand, keyCode: UInt32(kVK_Command), modifiers: UInt32(cmdKey))
        case .control:
            KeyboardShortcut(kind: .doubleControl, keyCode: UInt32(kVK_Control), modifiers: UInt32(controlKey))
        case .shift:
            KeyboardShortcut(kind: .doubleShift, keyCode: UInt32(kVK_Shift), modifiers: UInt32(shiftKey))
        }
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private static func keyName(for keyCode: UInt32) -> String {
        let namedKeys: [UInt32: String] = [
            UInt32(kVK_Space): "Space",
            UInt32(kVK_Return): "↩",
            UInt32(kVK_Tab): "⇥",
            UInt32(kVK_Delete): "⌫",
            UInt32(kVK_ForwardDelete): "⌦",
            UInt32(kVK_Escape): "Esc",
            UInt32(kVK_LeftArrow): "←",
            UInt32(kVK_RightArrow): "→",
            UInt32(kVK_UpArrow): "↑",
            UInt32(kVK_DownArrow): "↓",
            UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2",
            UInt32(kVK_F3): "F3", UInt32(kVK_F4): "F4",
            UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
            UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8",
            UInt32(kVK_F9): "F9", UInt32(kVK_F10): "F10",
            UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12"
        ]
        if let namedKey = namedKeys[keyCode] { return namedKey }

        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let rawData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "Key \(keyCode)"
        }

        let data = unsafeBitCast(rawData, to: CFData.self)
        guard let layoutPointer = CFDataGetBytePtr(data) else { return "Key \(keyCode)" }
        let keyboardLayout = UnsafeRawPointer(layoutPointer).assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &length,
            &characters
        )
        guard status == noErr, length > 0 else { return "Key \(keyCode)" }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}

struct DoubleModifierPressDetector {
    static let maximumInterval: TimeInterval = 0.4

    private var isModifierPressed = false
    private var previousPressTimestamp: TimeInterval?

    mutating func flagsChanged(
        modifierIsPressed: Bool,
        hasOtherModifiers: Bool,
        timestamp: TimeInterval
    ) -> Bool {
        if hasOtherModifiers {
            reset()
            isModifierPressed = modifierIsPressed
            return false
        }

        guard modifierIsPressed != isModifierPressed else { return false }
        isModifierPressed = modifierIsPressed
        guard modifierIsPressed else { return false }

        if let previousPressTimestamp,
           timestamp >= previousPressTimestamp,
           timestamp - previousPressTimestamp <= Self.maximumInterval {
            self.previousPressTimestamp = nil
            return true
        }

        previousPressTimestamp = timestamp
        return false
    }

    mutating func reset() {
        isModifierPressed = false
        previousPressTimestamp = nil
    }
}

@MainActor
final class GlobalHotKeyManager {
    var onPressed: (() -> Void)?

    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var modifierPollTimer: Timer?
    private var previousKeyDownEventCount: UInt32 = 0
    private var doubleModifierDetector = DoubleModifierPressDetector()
    private var monitoredDoubleModifier: KeyboardShortcut.DoubleTapModifier?

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(context).takeUnretainedValue()
                manager.onPressed?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        modifierPollTimer?.invalidate()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    /// Returns a human-readable error when macOS refuses the shortcut.
    func register(shortcut: KeyboardShortcut) -> String? {
        removeShortcutRegistration()

        if let modifier = shortcut.doubleTapModifier {
            return registerDoubleModifier(modifier)
        }

        let signature = OSType(0x42434E31) // "BCN1"
        let identifier = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )

        guard status == noErr else {
            return "That shortcut is already used by macOS or another app."
        }
        return nil
    }

    private func registerDoubleModifier(_ modifier: KeyboardShortcut.DoubleTapModifier) -> String? {
        monitoredDoubleModifier = modifier
        previousKeyDownEventCount = CGEventSource.counterForEventType(
            .combinedSessionState,
            eventType: .keyDown
        )

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pollModifierState()
            }
        }
        modifierPollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        return nil
    }

    private func pollModifierState() {
        let keyDownEventCount = CGEventSource.counterForEventType(
            .combinedSessionState,
            eventType: .keyDown
        )
        if keyDownEventCount != previousKeyDownEventCount {
            doubleModifierDetector.reset()
            previousKeyDownEventCount = keyDownEventCount
        }
        guard let modifier = monitoredDoubleModifier else { return }

        let flags = CGEventSource.flagsState(.combinedSessionState)
        let relevantFlags: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift, .maskSecondaryFn]
        let deviceFlags = flags.intersection(relevantFlags)
        var otherModifiers = deviceFlags
        otherModifiers.remove(modifier.cgEventFlag)
        let triggered = doubleModifierDetector.flagsChanged(
            modifierIsPressed: deviceFlags.contains(modifier.cgEventFlag),
            hasOtherModifiers: !otherModifiers.isEmpty,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        if triggered { onPressed?() }
    }

    private func removeShortcutRegistration() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        modifierPollTimer?.invalidate()
        modifierPollTimer = nil
        monitoredDoubleModifier = nil
        doubleModifierDetector.reset()
    }
}
