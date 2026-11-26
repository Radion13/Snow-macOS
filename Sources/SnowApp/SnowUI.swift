import AppKit
import SwiftUI

enum SnowTheme {
    static let background = Color(red: 0.065, green: 0.068, blue: 0.075)
    static let sidebar = Color(red: 0.085, green: 0.088, blue: 0.095)
    static let secondary = Color(red: 0.72, green: 0.73, blue: 0.76)
    static let silver = Color(red: 0.73, green: 0.75, blue: 0.81)
    static let line = Color.white.opacity(0.16)
    static let control = LinearGradient(colors: [Color(white: 0.23), Color(white: 0.16)], startPoint: .top, endPoint: .bottom)
    static let selected = LinearGradient(colors: [Color(red: 0.76, green: 0.78, blue: 0.83), Color(red: 0.51, green: 0.54, blue: 0.61)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct SnowButtonStyle: ButtonStyle {
    var selected = false
    var radius: CGFloat = 14
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor((selected ? Color(white: 0.10) : .white).opacity(enabled ? 0.96 : 0.36))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: radius).fill(selected ? SnowTheme.selected : SnowTheme.control))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(selected ? 0.48 : 0.20), lineWidth: 1))
            .brightness(configuration.isPressed ? -0.08 : 0)
            .opacity(enabled ? 1 : 0.6)
    }
}

struct SnowToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 16) {
                configuration.label.foregroundColor(.white.opacity(enabled ? 0.95 : 0.4))
                Spacer(minLength: 8)
                Capsule().fill(configuration.isOn ? SnowTheme.selected : SnowTheme.control)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(LinearGradient(colors: [.white, Color(white: 0.72)], startPoint: .top, endPoint: .bottom))
                            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                            .padding(3).frame(width: 26, height: 26)
                    }
                    .frame(width: 48, height: 27).opacity(enabled ? 1 : 0.4)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityValue(tr(configuration.isOn ? "ui.on" : "ui.off"))
    }
}

struct SnowSegmented<Value: Hashable>: View {
    @Binding var selection: Value
    let choices: [(Value, String)]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(choices.indices, id: \.self) { index in
                let item = choices[index]
                Button { selection = item.0 } label: {
                    Text(item.1).font(.system(size: 14, weight: selection == item.0 ? .semibold : .regular))
                        .foregroundColor(selection == item.0 ? Color(white: 0.10) : .white)
                        .frame(maxWidth: .infinity).frame(minHeight: 35)
                        .background {
                            if selection == item.0 {
                                Capsule().fill(SnowTheme.selected)
                                    .overlay(Capsule().strokeBorder(.white.opacity(0.46), lineWidth: 1))
                            }
                        }.contentShape(Capsule())
                }.buttonStyle(.plain)
                    .accessibilityAddTraits(selection == item.0 ? [.isSelected] : [])
            }
        }.padding(1)
            .background(Capsule().fill(SnowTheme.control))
            .overlay(Capsule().strokeBorder(.white.opacity(0.24), lineWidth: 1))
    }
}

struct SnowMenuOption {
    let title: String
    var selected = false
    var action: (() -> Void)?
    static var separator: Self { .init(title: "") }
}

/// The complete visible surface is the native popup button, including its
/// chevron. Menu actions retain AppKit tracking, keyboard and accessibility.
struct SnowMenu: NSViewRepresentable {
    let title: String
    var symbol: String? = nil
    var identifier: String? = nil
    let options: [SnowMenuOption]
    @Environment(\.isEnabled) private var enabled
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> SnowPopupButton {
        let button = SnowPopupButton(frame: .zero, pullsDown: true)
        button.isBordered = false
        button.focusRingType = .default
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = context.coordinator
        button.menu = menu
        return button
    }
    func updateNSView(_ button: SnowPopupButton, context: Context) {
        button.displayTitle = title; button.displaySymbol = symbol
        button.isEnabled = enabled
        button.identifier = identifier.map { NSUserInterfaceItemIdentifier($0) }
        button.setAccessibilityIdentifier(identifier ?? title)
        button.setAccessibilityLabel(title)
        button.needsDisplay = true
        context.coordinator.title = title
        context.coordinator.options = options
        if !context.coordinator.tracking, let menu = button.menu { context.coordinator.rebuild(menu) }
    }
    final class Coordinator: NSObject, NSMenuDelegate {
        var title = ""
        var options: [SnowMenuOption] = []
        var tracking = false
        func rebuild(_ menu: NSMenu) {
            menu.removeAllItems()
            let label = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            label.isHidden = true; menu.addItem(label)
            for (index, option) in options.enumerated() {
                guard option.action != nil else { menu.addItem(.separator()); continue }
                let item = NSMenuItem(title: option.title, action: #selector(select(_:)), keyEquivalent: "")
                item.target = self; item.representedObject = index
                item.state = option.selected ? .on : .off
                menu.addItem(item)
            }
        }
        func menuNeedsUpdate(_ menu: NSMenu) { if !tracking { rebuild(menu) } }
        func menuWillOpen(_ menu: NSMenu) { tracking = true }
        func menuDidClose(_ menu: NSMenu) { tracking = false }
        @objc private func select(_ item: NSMenuItem) {
            guard let index = item.representedObject as? Int, options.indices.contains(index) else { return }
            options[index].action?()
        }
    }
}

final class SnowPopupButton: NSPopUpButton {
    var displayTitle = ""
    var displaySymbol: String?
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 36) }
    override var focusRingMaskBounds: NSRect { bounds }
    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12).fill()
    }
    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        NSGradient(starting: NSColor(white: 0.23, alpha: 1), ending: NSColor(white: 0.16, alpha: 1))?.draw(in: path, angle: 90)
        NSColor.white.withAlphaComponent(isEnabled ? 0.24 : 0.12).setStroke()
        path.lineWidth = 1; path.stroke()
        var left: CGFloat = 13
        if let symbol = displaySymbol, let source = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let icon = NSImage(size: CGSize(width: 18, height: 18), flipped: false) { imageRect in
                source.draw(in: imageRect)
                NSColor.white.setFill(); imageRect.fill(using: .sourceAtop)
                return true
            }
            icon.draw(in: CGRect(x: left, y: bounds.midY - 9, width: 18, height: 18), from: .zero, operation: .sourceOver, fraction: isEnabled ? 0.95 : 0.4, respectFlipped: true, hints: nil)
            left += 28
        }
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        (displayTitle as NSString).draw(in: NSRect(x: left, y: bounds.midY - 9, width: max(0, bounds.width - left - 34), height: 19),
            withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.white.withAlphaComponent(isEnabled ? 0.96 : 0.4), .paragraphStyle: paragraph])
        let chevron = NSBezierPath()
        let top = bounds.midY + (isFlipped ? -2 : 2), bottom = bounds.midY + (isFlipped ? 2 : -2)
        chevron.move(to: NSPoint(x: bounds.maxX - 23, y: top))
        chevron.line(to: NSPoint(x: bounds.maxX - 19, y: bottom))
        chevron.line(to: NSPoint(x: bounds.maxX - 15, y: top))
        chevron.lineWidth = 1.6; chevron.lineCapStyle = .round; chevron.lineJoinStyle = .round
        NSColor.white.withAlphaComponent(isEnabled ? 0.9 : 0.35).setStroke(); chevron.stroke()
    }
}

struct SnowCleanupActions: View {
    @ObservedObject var store: SettingsStore
    var emphasizeCleaner = false
    var showsCleanerHelp = false
    var body: some View {
        VStack(spacing: 10) {
            Button { store.onClean?() } label: {
                HStack(spacing: 10) {
                    SnowCleaningIcon().stroke(lineWidth: 1.4).frame(width: 18, height: 20).accessibilityHidden(true)
                    Text(tr("cleaner.run")); Spacer(minLength: 0)
                }.frame(maxWidth: .infinity)
            }.buttonStyle(SnowButtonStyle(selected: emphasizeCleaner))
                .accessibilityIdentifier("cleanup.cleaner")
                .disabled(store.effectPaused || store.effectsHidden)
            if showsCleanerHelp {
                Text(tr(store.effectPaused ? "cleaner.paused" : "ui.cleaner.windowsHelp"))
                    .font(.system(size: 12)).foregroundColor(SnowTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { store.onClear?() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sun.max").font(.system(size: 19, weight: .light))
                        .frame(width: 18, height: 20).accessibilityHidden(true)
                    Text(tr("menu.clear")); Spacer(minLength: 0)
                }.frame(maxWidth: .infinity)
            }.buttonStyle(SnowButtonStyle())
                .accessibilityIdentifier("cleanup.melt")
        }
    }
}

enum SnowPopoverLayout {
    static let scale: CGFloat = 0.8625
    static let designWidth: CGFloat = 360
    static let width: CGFloat = (designWidth * scale).rounded(.up)
    static let preferredHeight: CGFloat = (780 * scale).rounded(.up)
    static let rowSpacing: CGFloat = 7
    static let headerSpacing: CGFloat = 24
    static let dividerSpacing: CGFloat = 16
    static func contentHeight(visibleFrame: CGRect, anchor: CGRect) -> CGFloat {
        let below = min(visibleFrame.height, anchor.minY - visibleFrame.minY)
        return max(1, min(preferredHeight, below - 44))
    }
    static func constrain(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        let safe = visibleFrame.insetBy(dx: 6, dy: 6)
        var result = frame
        result.origin.x = max(safe.minX, min(result.origin.x, safe.maxX - frame.width))
        result.origin.y = max(safe.minY, min(result.origin.y, safe.maxY - frame.height))
        return result
    }
}

/// An AppKit slider keeps native keyboard and accessibility behavior while drawing
/// the same graphite track and silver thumb as the other controls.
struct SnowSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var valueDescription: String? = nil
    let label: String
    @Environment(\.isEnabled) private var enabled
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider()
        slider.cell = SnowSliderCell()
        slider.isContinuous = true
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.changed(_:))
        slider.focusRingType = .default
        return slider
    }
    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.parent = self
        slider.minValue = range.lowerBound; slider.maxValue = range.upperBound
        slider.doubleValue = value; slider.altIncrementValue = step
        slider.isEnabled = enabled
        slider.setAccessibilityLabel(label)
        slider.setAccessibilityValueDescription(valueDescription)
        slider.toolTip = label
        slider.needsDisplay = true
    }
    final class Coordinator: NSObject {
        var parent: SnowSlider
        init(_ parent: SnowSlider) { self.parent = parent }
        @objc func changed(_ sender: NSSlider) {
            let rounded = parent.range.lowerBound + ((sender.doubleValue - parent.range.lowerBound) / parent.step).rounded() * parent.step
            parent.value = min(parent.range.upperBound, max(parent.range.lowerBound, rounded))
        }
    }
}

private final class SnowSliderCell: NSSliderCell {
    override var knobThickness: CGFloat { 22 }
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let track = NSRect(x: rect.minX, y: rect.midY - 5, width: rect.width, height: 10)
        let path = NSBezierPath(roundedRect: track, xRadius: 5, yRadius: 5)
        NSGradient(starting: NSColor(white: 0.24, alpha: 1), ending: NSColor(white: 0.17, alpha: 1))?.draw(in: path, angle: 90)
        NSColor.white.withAlphaComponent(isEnabled ? 0.25 : 0.1).setStroke(); path.lineWidth = 0.8; path.stroke()
        let fraction = CGFloat((doubleValue - minValue) / max(0.001, maxValue - minValue))
        let fill = NSBezierPath(roundedRect: NSRect(x: track.minX, y: track.minY, width: max(0, track.width * fraction), height: track.height), xRadius: 5, yRadius: 5)
        NSGradient(starting: NSColor(white: 0.82, alpha: isEnabled ? 1 : 0.3), ending: NSColor(white: 0.57, alpha: isEnabled ? 1 : 0.3))?.draw(in: fill, angle: 90)
    }
    override func drawKnob(_ knobRect: NSRect) {
        let rect = NSRect(x: knobRect.midX - 10, y: knobRect.midY - 10, width: 20, height: 20)
        let path = NSBezierPath(ovalIn: rect)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = 2; shadow.shadowOffset = NSSize(width: 0, height: -1); shadow.set()
        NSGradient(starting: NSColor(white: 0.9, alpha: isEnabled ? 1 : 0.4), ending: NSColor(white: 0.62, alpha: isEnabled ? 1 : 0.4))?.draw(in: path, angle: 90)
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.7).setStroke(); path.lineWidth = 0.8; path.stroke()
    }
}

struct SnowRule: View {
    var body: some View { Rectangle().fill(SnowTheme.line).frame(height: 1).accessibilityHidden(true) }
}

struct SnowPauseButton: View {
    @ObservedObject var store: SettingsStore
    var body: some View {
        Button { store.onTogglePause?() } label: {
            Image(systemName: store.userPaused ? "play.fill" : "pause.fill").frame(width: 17, height: 22)
        }.buttonStyle(SnowButtonStyle(selected: true, radius: 24))
            .help(tr(store.userPaused ? "menu.resume" : "menu.pause"))
            .accessibilityLabel(tr(store.userPaused ? "menu.resume" : "menu.pause"))
    }
}

struct SnowToolIcon: View {
    let tool: SnowTool
    var body: some View {
        Group {
            switch tool {
            case .mitten, .shovel, .snowball:
                SnowToolGlyph(tool: tool).stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            case .delete: Image(systemName: "trash")
            }
        }.frame(width: 23, height: 25)
    }
}

/// The same local outline family as SnowCleaningIcon, with distinct shapes for
/// the three game tools. These vectors stay sharp at every display scale.
private struct SnowToolGlyph: Shape {
    let tool: SnowTool
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        var path = Path()
        switch tool {
        case .mitten:
            path.move(to: p(0.25, 0.82)); path.addLine(to: p(0.25, 0.72))
            path.addCurve(to: p(0.18, 0.29), control1: p(0.13, 0.58), control2: p(0.18, 0.42))
            path.addCurve(to: p(0.61, 0.29), control1: p(0.18, 0.02), control2: p(0.61, 0.02))
            path.addLine(to: p(0.61, 0.45))
            path.addCurve(to: p(0.86, 0.42), control1: p(0.76, 0.26), control2: p(0.92, 0.31))
            path.addCurve(to: p(0.64, 0.76), control1: p(0.90, 0.54), control2: p(0.70, 0.69))
            path.addLine(to: p(0.64, 0.82)); path.closeSubpath()
            path.addRoundedRect(in: CGRect(x: rect.minX + rect.width * 0.23, y: rect.minY + rect.height * 0.82, width: rect.width * 0.43, height: rect.height * 0.12), cornerSize: CGSize(width: 1, height: 1))
        case .shovel:
            path.move(to: p(0.32, 0.06)); path.addLine(to: p(0.68, 0.06))
            path.addQuadCurve(to: p(0.32, 0.06), control: p(0.5, 0.43)); path.closeSubpath()
            path.move(to: p(0.5, 0.22)); path.addLine(to: p(0.5, 0.59))
            path.addRoundedRect(in: CGRect(x: rect.minX + rect.width * 0.23, y: rect.minY + rect.height * 0.59, width: rect.width * 0.54, height: rect.height * 0.34), cornerSize: CGSize(width: 2, height: 2))
            for x: CGFloat in [0.4, 0.6] { path.move(to: p(x, 0.7)); path.addLine(to: p(x, 0.84)) }
        case .snowball:
            path.addEllipse(in: rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1))
            path.move(to: p(0.39, 0.72)); path.addQuadCurve(to: p(0.74, 0.39), control: p(0.76, 0.75))
        case .delete: break
        }
        return path
    }
}

struct SnowDisplayMenu: View {
    @ObservedObject var store: SettingsStore
    var title: String {
        if store.value.allDisplays { return tr("ui.allDisplays") }
        let chosen = store.displayList.filter { store.value.displayIDs.contains($0.id) }
        if chosen.count == 1 { return chosen[0].name }
        return chosen.isEmpty ? tr("status.noDisplays") : String(chosen.count) + " " + tr("ui.displaysCount")
    }
    var body: some View {
        SnowMenu(title: title, symbol: "display", identifier: "displays.selection", options: options)
            .frame(height: 36).id(store.language)
    }
    private var options: [SnowMenuOption] {
        var result = [SnowMenuOption(title: tr("displays.all"), selected: store.value.allDisplays,
                                     action: { store.value.allDisplays.toggle() }), .separator]
        result += store.displayList.map { display in
            SnowMenuOption(title: display.name, selected: store.value.allDisplays || store.value.displayIDs.contains(display.id), action: {
                let enabled = !(store.value.allDisplays || store.value.displayIDs.contains(display.id))
                var next = store.value
                if next.allDisplays {
                    next.displayIDs = Set(store.displayList.map(\.id)); next.allDisplays = false
                }
                if enabled { next.displayIDs.insert(display.id) } else { next.displayIDs.remove(display.id) }
                store.value = next
            })
        }
        return result
    }
}
