import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var model: LauncherModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.beaconInk)
                        .frame(width: 42, height: 42)
                        .background(Color.beaconSelection)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Beacon")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("Launcher settings")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.beaconMuted)
                    }
                }
            }
            .padding(24)

            Divider().opacity(0.65)

            VStack(alignment: .leading, spacing: 24) {
                settingSection(
                    title: "Open shortcut",
                    detail: "Use this shortcut anywhere in macOS to show or hide Beacon."
                ) {
                    HStack(spacing: 12) {
                        ShortcutRecorder(shortcut: model.shortcut) { shortcut in
                            model.updateShortcut(shortcut)
                        }
                        .frame(width: 174, height: 38)
                        .accessibilityIdentifier("shortcutRecorder")

                        Button("Reset") {
                            model.resetShortcut()
                        }
                        .buttonStyle(.borderless)
                    }
                }

                if let error = model.shortcutRegistrationError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.57, green: 0.25, blue: 0.22))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.98, green: 0.92, blue: 0.91))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(24)

            Spacer(minLength: 0)

            Text("Beacon \(appVersion)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.beaconMuted)
                .padding(24)
        }
        .frame(width: 720, height: 500)
        .background(Color.beaconCanvas)
        .preferredColorScheme(.light)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private func settingSection<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.beaconInk)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.beaconMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content()
                .frame(width: 205, alignment: .leading)
        }
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: KeyboardShortcut
    let onChange: (KeyboardShortcut) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.shortcut = shortcut
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: ShortcutRecorderView, context: Context) {
        view.shortcut = shortcut
        view.onChange = onChange
        view.needsDisplay = true
    }
}

private final class ShortcutRecorderView: NSView {
    var shortcut = KeyboardShortcut.default
    var onChange: ((KeyboardShortcut) -> Void)?
    private var isRecording = false
    private var doubleModifierDetectors = Dictionary(
        uniqueKeysWithValues: KeyboardShortcut.DoubleTapModifier.allCases.map {
            ($0, DoubleModifierPressDetector())
        }
    )

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        resetDoubleModifierDetectors()
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        resetDoubleModifierDetectors()
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }

        let deviceFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]
        var detectedModifier: KeyboardShortcut.DoubleTapModifier?

        for modifier in KeyboardShortcut.DoubleTapModifier.allCases {
            var detector = doubleModifierDetectors[modifier] ?? DoubleModifierPressDetector()
            var otherModifiers = deviceFlags.intersection(relevantModifiers)
            otherModifiers.remove(modifier.eventFlag)
            if detector.flagsChanged(
                modifierIsPressed: deviceFlags.contains(modifier.eventFlag),
                hasOtherModifiers: !otherModifiers.isEmpty,
                timestamp: event.timestamp
            ) {
                detectedModifier = modifier
            }
            doubleModifierDetectors[modifier] = detector
        }
        guard let detectedModifier else { return }

        let newShortcut = KeyboardShortcut.doubleTap(detectedModifier)
        shortcut = newShortcut
        isRecording = false
        onChange?(newShortcut)
        window?.makeFirstResponder(nil)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            isRecording = false
            window?.makeFirstResponder(nil)
            needsDisplay = true
            return
        }

        resetDoubleModifierDetectors()
        let newShortcut = KeyboardShortcut(event: event)
        guard newShortcut.modifiers != 0 else {
            NSSound.beep()
            return
        }
        shortcut = newShortcut
        isRecording = false
        onChange?(newShortcut)
        window?.makeFirstResponder(nil)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 7, yRadius: 7)
        (isRecording ? NSColor.white : NSColor(calibratedWhite: 1, alpha: 0.62)).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.75) : NSColor.black.withAlphaComponent(0.10)).setStroke()
        path.lineWidth = isRecording ? 1.5 : 1
        path.stroke()

        let text = isRecording ? "Press keys or double-tap a modifier…" : shortcut.displayName
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor,
            .paragraphStyle: style
        ]
        let height = (text as NSString).size(withAttributes: attributes).height
        (text as NSString).draw(
            in: NSRect(x: 8, y: (bounds.height - height) / 2, width: bounds.width - 16, height: height),
            withAttributes: attributes
        )
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private func resetDoubleModifierDetectors() {
        for modifier in KeyboardShortcut.DoubleTapModifier.allCases {
            var detector = doubleModifierDetectors[modifier] ?? DoubleModifierPressDetector()
            detector.reset()
            doubleModifierDetectors[modifier] = detector
        }
    }
}

#Preview {
    SettingsView(model: LauncherModel.preview)
}
