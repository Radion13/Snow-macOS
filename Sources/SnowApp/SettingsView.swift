import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @State private var resetConfirmation = false
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "snowflake").font(.title).foregroundStyle(.secondary).accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text(tr("app.name")).font(.title2.weight(.semibold))
                        Text(store.statusMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 16).padding(.top, 20)
                List(SettingsPane.visibleCases, selection: $store.selectedPane) { pane in
                    Label {
                        Text(tr("section." + pane.rawValue))
                    } icon: {
                        if pane == .cleaner {
                            SnowCleaningIcon().stroke(style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round))
                                .frame(width: 18, height: 18).accessibilityHidden(true)
                        } else {
                            Image(systemName: pane.symbol)
                        }
                    }.tag(pane)
                }.listStyle(.sidebar)
                Text(tr("settings.footer")).font(.caption).foregroundStyle(.secondary).padding(16)
            }.frame(width: 205)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(tr("section." + store.activePane.rawValue)).font(.title2.weight(.semibold))
                    content
                }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.frame(width: 800, height: 600)
        .alert(tr("reset.title"), isPresented: $resetConfirmation) {
            Button(tr("reset.confirm"), role: .destructive) { store.reset() }
            Button(tr("cancel"), role: .cancel) {}
        } message: { Text(tr("reset.body")) }
    }
    @ViewBuilder private var content: some View {
        switch store.activePane {
        case .snow:
            Picker(tr("snow.weather"), selection: $store.value.weather) {
                ForEach(SnowWeather.allCases, id: \.self) { Text(tr("weather." + $0.rawValue)).tag($0) }
            }.pickerStyle(.segmented)
            Picker(tr("snow.appearance"), selection: $store.value.snowAppearance) {
                ForEach(SnowAppearance.allCases, id: \.self) { Text(tr("snow.appearance." + $0.rawValue)).tag($0) }
            }.pickerStyle(.segmented)
            help("snow.appearance.help")
            Divider()
            Picker(tr("snowflakes.style"), selection: $store.value.snowflakeStyle) {
                ForEach(SnowflakeStyle.allCases, id: \.self) { Text(tr("snowflakes." + $0.rawValue)).tag($0) }
            }.pickerStyle(.segmented)
            if SnowAppFeatures.snowflakePreviews && store.value.snowflakeStyle == .patterned {
                HStack(spacing: 8) {
                    ForEach(0..<SnowflakeArt.variantCount, id: \.self) { index in
                        Image(nsImage: SnowflakeArt.preview(variant: index)).resizable().frame(width: 40, height: 40).accessibilityHidden(true)
                    }
                }
            }
            row("snowflakes.size", value: "\(Int((store.value.snowflakeSize * 100).rounded()))%")
            Slider(value: $store.value.snowflakeSize, in: 0.5...3, step: 0.1) { Text(tr("snowflakes.size")) }
                .labelsHidden().accessibilityLabel(tr("snowflakes.size"))
                .accessibilityValue("\(Int((store.value.snowflakeSize * 100).rounded()))%")
            help("snowflakes.help")
            Divider()
            Toggle(tr("snow.sweep"), isOn: $store.value.decorativeSweep)
            help("snow.sweep.help"); help("snow.game.help")
            Divider()
            Toggle(tr("tree.grow"), isOn: Binding(get: { store.treeShown }, set: { enabled in
                if enabled { store.onGrowTree?() } else { store.onRemoveTree?() }
            })).toggleStyle(.switch).disabled(store.effectPaused && !store.treeShown)
            help("tree.help")
            if store.effectPaused { help("tree.paused") }
        case .wind:
            help("wind.help")
            row("wind.direction", value: String(Int(store.value.wind)))
            Slider(value: $store.value.wind, in: -100...100, step: 1) { Text(tr("wind.direction")) }
                .labelsHidden().accessibilityLabel(tr("wind.direction"))
                .accessibilityValue(String(Int(store.value.wind)))
            HStack { Text(tr("wind.left")); Spacer(); Text(tr("wind.calm")); Spacer(); Text(tr("wind.right")) }.font(.caption)
            Button(tr("wind.reset")) { store.value.wind = 0 }
        case .accumulation:
            Toggle(tr("accumulation.windows"), isOn: $store.value.accumulateOnWindows).disabled(!store.windowsAvailable)
            row("accumulation.windowHeight", value: "\(Int(store.value.windowHeight)) \(tr("points"))")
            Slider(value: $store.value.windowHeight, in: 4...36, step: 1) { Text(tr("accumulation.windowHeight")) }
                .labelsHidden().accessibilityLabel(tr("accumulation.windowHeight"))
                .accessibilityValue("\(Int(store.value.windowHeight)) \(tr("points"))")
                .disabled(!store.value.accumulateOnWindows)
            Text(store.windowGeometryMessage).font(.callout).foregroundStyle(.secondary)
            Divider()
            Toggle(tr("accumulation.bottom"), isOn: $store.value.accumulateAtBottom)
            row("accumulation.bottomHeight", value: "\(Int(store.value.bottomHeight)) \(tr("points"))")
            Slider(value: $store.value.bottomHeight, in: 8...96, step: 1) { Text(tr("accumulation.bottomHeight")) }
                .labelsHidden().accessibilityLabel(tr("accumulation.bottomHeight"))
                .accessibilityValue("\(Int(store.value.bottomHeight)) \(tr("points"))")
                .disabled(!store.value.accumulateAtBottom)
            help("accumulation.height.help"); Divider()
            Toggle(tr("dock.toggle"), isOn: $store.value.accumulateOnDock)
            Toggle(tr("dock.vertical"), isOn: $store.value.verticalDock).disabled(!store.value.accumulateOnDock)
            Text(store.dockMessage).font(.callout).foregroundStyle(.secondary)
            if SnowAppFeatures.widgetSnow {
                Toggle(tr("widgets.toggle"), isOn: $store.value.accumulateOnWidgets)
                Text(store.widgetMessage).font(.callout).foregroundStyle(.secondary)
            }
            help("surfaces.experimental")
        case .play:
            Picker(tr("menu.tool"), selection: $store.selectedTool) {
                ForEach(SnowTool.allCases, id: \.self) { tool in Text(tr("tool." + tool.rawValue)).tag(tool) }
            }
            Button(tr("game.start")) { store.onPlay?() }.disabled(store.effectPaused)
            help("game.instructions"); help("game.stacking"); help("game.limits"); help("game.delete")
        case .cleaner:
            Picker(tr("cleaner.character"), selection: $store.value.cleaner) {
                ForEach(CleanerCharacter.allCases, id: \.self) { character in
                    Text(tr("cleaner." + character.rawValue)).tag(character)
                }
            }
            Button(tr("cleaner.run")) { store.onClean?() }.disabled(store.effectPaused)
            if store.effectPaused { help("cleaner.paused") }
            Toggle(tr("cleaner.auto"), isOn: $store.value.automaticCleaner); help("cleaner.auto.help")
            if SnowAppFeatures.bladeImages {
                Toggle(tr("cleaner.blade"), isOn: $store.value.useBladeImage).disabled(ImportedAssets.image(for: .blade) == nil)
                help("cleaner.blade.help"); Divider()
                ImportImageView(importer: store.importer)
            }
        case .garlands:
            HStack(spacing: 8) {
                ForEach(GarlandStyle.allCases, id: \.self) { style in
                    Button {
                        store.value.garlandStyle = style
                        if store.value.garland == .off { store.value.garland = .steady }
                    } label: {
                        VStack(spacing: 8) {
                            Image(nsImage: ScreenGarlandRenderer.preview(style: style, palette: store.value.garlandPalette))
                                .resizable().scaledToFit().accessibilityHidden(true)
                            Text(tr("garland.style." + style.rawValue)).font(.caption).multilineTextAlignment(.center)
                        }.padding(6)
                            .background(store.value.garlandStyle == style ? Color.accentColor.opacity(0.18) : Color.clear)
                            .cornerRadius(8)
                    }.buttonStyle(.plain).accessibilityLabel(tr("garland.style." + style.rawValue))
                }
            }
            Picker(tr("garland.mode"), selection: $store.value.garland) {
                ForEach(GarlandMode.allCases, id: \.self) { Text(tr("garland." + $0.rawValue)).tag($0) }
            }
            Picker(tr("garland.palette"), selection: $store.value.garlandPalette) {
                ForEach(GarlandPalette.allCases, id: \.self) { Text(tr("palette." + $0.rawValue)).tag($0) }
            }.disabled(store.value.garland == .off)
            percentageSlider("garland.brightness", value: $store.value.garlandBrightness)
            percentageSlider("garland.intensity", value: $store.value.garlandBlinkIntensity)
                .disabled((store.value.garland == .off || store.value.garland == .steady) && !store.treeShown)
            help("garland.intensity.help")
            help("garland.help")
        case .scenes:
            ForEach(store.displayList, id: \.id) { display in
                Picker(display.name, selection: Binding<WinterScene>(get: { store.value.scenes[display.id] ?? WinterScene.none }, set: { store.value.scenes[display.id] = $0 })) {
                    ForEach(WinterScene.allCases, id: \.self) { Text(tr("scene." + $0.rawValue)).tag($0) }
                }
            }
            help("scene.help"); help("scene.displays.help")
        case .displays:
            Toggle(tr("displays.all"), isOn: $store.value.allDisplays)
            ForEach(store.displayList, id: \.id) { display in
                Toggle(display.name, isOn: Binding(get: { store.value.allDisplays || store.value.displayIDs.contains(display.id) }, set: { enabled in
                    if enabled { store.value.displayIDs.insert(display.id) } else { store.value.displayIDs.remove(display.id) }
                })).disabled(store.value.allDisplays)
            }
            help("displays.help"); help("displays.fullscreen.help")
        case .performance:
            Picker(tr("performance.quality"), selection: $store.value.quality) {
                ForEach(SnowQuality.allCases, id: \.self) { Text(tr("quality." + $0.rawValue)).tag($0) }
            }
            help("performance.help")
            Toggle(tr("performance.reduceMotion"), isOn: $store.value.respectReduceMotion); help("performance.reduceMotion.help")
        case .general:
            Toggle(tr("login.toggle"), isOn: Binding(get: { store.loginEnabled }, set: { store.setLoginEnabled($0) }))
            Text(store.loginMessage).font(.callout).foregroundStyle(.secondary)
            Button(tr("login.settings")) { store.openLoginSettings() }
            Divider(); help("privacy.body")
            Button(tr("reset.button")) { resetConfirmation = true }
            Text("Snow \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · macOS 12+").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func help(_ key: String) -> some View { Text(tr(key)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
    private func percentageSlider(_ key: String, value: Binding<Double>) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(tr(key)); Spacer()
                Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...1) { Text(tr(key)) }
                .labelsHidden()
                .accessibilityValue(Text(value.wrappedValue, format: .percent.precision(.fractionLength(0))))
        }
    }
    private func row(_ key: String, value: String) -> some View { HStack { Text(tr(key)); Spacer(); Text(value).foregroundStyle(.secondary) } }
}

/// Local outline artwork, independent of newer system symbol catalogs.
private struct SnowCleaningIcon: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: point(0.48, 0.46)); path.addLine(to: point(0.85, 0.08))
        path.move(to: point(0.34, 0.48)); path.addLine(to: point(0.46, 0.37))
        path.addLine(to: point(0.62, 0.53)); path.addLine(to: point(0.50, 0.65)); path.closeSubpath()
        path.move(to: point(0.34, 0.48)); path.addQuadCurve(to: point(0.08, 0.64), control: point(0.20, 0.49))
        path.addQuadCurve(to: point(0.40, 0.94), control: point(0.18, 0.84))
        path.addQuadCurve(to: point(0.50, 0.65), control: point(0.49, 0.79)); path.closeSubpath()
        path.move(to: point(0.18, 0.71)); path.addLine(to: point(0.37, 0.59))
        path.move(to: point(0.29, 0.82)); path.addLine(to: point(0.42, 0.64))
        return path
    }
}

private struct ImportImageView: View {
    @ObservedObject var importer: ImageImporter
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("import.title")).font(.headline)
            Text(tr("import.help")).font(.callout).foregroundStyle(.secondary)
            Button(tr("import.choose")) { importer.choose() }.disabled(importer.busy)
            if importer.busy { ProgressView().controlSize(.small) }
            if let draft = importer.draft {
                Image(nsImage: draft).resizable().scaledToFit().frame(maxWidth: 240, maxHeight: 140)
                    .background(Color.secondary.opacity(0.08)).accessibilityLabel(tr("import.preview"))
                Button(tr("import.background")) { importer.removeBackground() }.disabled(!importer.canRemoveBackground || importer.busy || importer.backgroundProcessed)
                if importer.backgroundProcessed { Text(tr("import.background.done")).font(.caption).foregroundStyle(.secondary) }
                if !importer.canRemoveBackground { Text(tr("import.background.unavailable")).font(.caption).foregroundStyle(.secondary) }
                HStack {
                    Button(tr("import.use")) { importer.commit() }.disabled(importer.busy)
                    Button(tr("cancel")) { importer.cancel() }
                }
            }
            if let error = importer.error { Text(error).foregroundStyle(.red).font(.callout) }
        }
    }
}
