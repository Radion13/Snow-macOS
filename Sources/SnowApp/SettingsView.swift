import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @State private var resetConfirmation = false
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 230)
            Rectangle().fill(SnowTheme.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(paneTitle(store.activePane)).font(.system(size: 24, weight: .semibold))
                        Text(tr("ui.subtitle." + store.activePane.rawValue)).font(.system(size: 13)).foregroundColor(SnowTheme.secondary)
                    }
                    Spacer()
                    SnowPauseButton(store: store)
                }.padding(.horizontal, 26).padding(.top, 25).padding(.bottom, 19)
                SnowRule().padding(.horizontal, 26)
                ScrollView {
                    HStack(alignment: .top, spacing: 28) {
                        VStack(alignment: .leading, spacing: 18) { content }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if store.activePane == .general {
                            privacy.frame(width: 260, alignment: .leading)
                        } else if store.activePane != .scenes {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(tr("ui.preview")).font(.system(size: 15, weight: .semibold))
                                SettingsPreview(store: store)
                                if store.activePane != .displays { SnowDisplayMenu(store: store) }
                                else { help("ui.displays.preview") }
                            }.frame(width: 260)
                        }
                    }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(spacing: 10) {
                    SnowRule()
                    HStack {
                        Text(tr("ui.autosave")).font(.system(size: 12)).foregroundColor(SnowTheme.secondary)
                        Spacer()
                    }
                }.padding(.horizontal, 26).padding(.bottom, 18)
            }
        }.frame(width: 1040, height: 660)
            .font(.system(size: 14))
            .foregroundColor(.white)
            .background(SnowTheme.background)
            .accentColor(SnowTheme.silver)
            .preferredColorScheme(.dark)
            .environment(\.locale, store.language.locale)
            .alert(tr("reset.title"), isPresented: $resetConfirmation) {
                Button(tr("reset.confirm"), role: .destructive) { store.reset() }
                Button(tr("cancel"), role: .cancel) {}
            } message: { Text(tr("reset.body")) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "snowflake").font(.system(size: 31, weight: .light)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("app.name")).font(.system(size: 19, weight: .semibold))
                    Text(store.statusMessage).font(.system(size: 12)).foregroundColor(SnowTheme.secondary)
                }
            }.padding(.horizontal, 20).padding(.top, 47).padding(.bottom, 24)
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(SettingsPane.visibleCases) { pane in
                        Button { store.selectedPane = pane } label: {
                            HStack(spacing: 12) {
                                if pane == .cleaner {
                                    SnowCleaningIcon().stroke(style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)).frame(width: 22, height: 23)
                                } else if pane == .play {
                                    SnowToolIcon(tool: .mitten).frame(width: 22, height: 23)
                                } else {
                                    Image(systemName: pane.symbol).font(.system(size: 20, weight: .light)).frame(width: 22)
                                }
                                Text(paneTitle(pane)).font(.system(size: 13.5)).lineLimit(1)
                                Spacer(minLength: 0)
                            }.foregroundColor(store.activePane == pane ? Color(white: 0.10) : .white)
                                .padding(.horizontal, 13).frame(height: 39)
                                .background {
                                    if store.activePane == pane {
                                        RoundedRectangle(cornerRadius: 10).fill(SnowTheme.selected)
                                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.4), lineWidth: 0.8))
                                    }
                                }.contentShape(RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier("settings.tab." + pane.rawValue)
                            .accessibilityAddTraits(store.activePane == pane ? [.isSelected] : [])
                    }
                }.padding(.horizontal, 10)
            }
            Spacer(minLength: 10)
            Menu {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Button { store.selectLanguage(language) } label: {
                        if store.language == language { Label(language.name, systemImage: "checkmark") }
                        else { Text(language.name) }
                    }
                }
            } label: {
                Label(store.language.name, systemImage: "globe").font(.system(size: 12)).foregroundColor(SnowTheme.secondary)
            }.menuStyle(.borderlessButton).fixedSize().padding(.horizontal, 20).padding(.bottom, 20)
        }.background(SnowTheme.sidebar)
    }

    private func paneTitle(_ pane: SettingsPane) -> String {
        tr(pane == .play ? "ui.playTitle" : "section." + pane.rawValue)
    }
    @ViewBuilder private var content: some View {
        switch store.activePane {
        case .snow: snow
        case .wind: wind
        case .accumulation: accumulation
        case .play: play
        case .cleaner: cleaner
        case .garlands: garlands
        case .displays: displays
        case .performance: performance
        case .general: general
        case .scenes:
            ForEach(store.displayList, id: \.id) { display in
                Picker(display.name, selection: Binding<WinterScene>(
                    get: { store.value.scenes[display.id] ?? .none },
                    set: { store.value.scenes[display.id] = $0 })) {
                    ForEach(WinterScene.allCases, id: \.self) { Text(tr("scene." + $0.rawValue)).tag($0) }
                }.id(store.language)
            }
            help("scene.help")
        }
    }
    private var snow: some View {
        Group {
            field("snow.weather") {
                SnowSegmented(selection: $store.value.weather, choices: SnowWeather.allCases.map { ($0, tr("weather." + $0.rawValue)) })
            }
            field("snow.appearance") {
                SnowSegmented(selection: $store.value.snowAppearance, choices: SnowAppearance.allCases.map { ($0, tr("snow.appearance." + $0.rawValue)) })
                help("ui.snow.textureHelp")
            }
            SnowRule()
            field("snowflakes.style") {
                SnowSegmented(selection: $store.value.snowflakeStyle, choices: SnowflakeStyle.allCases.map { ($0, tr("snowflakes." + $0.rawValue)) })
            }
            if SnowAppFeatures.snowflakePreviews && store.value.snowflakeStyle == .patterned {
                HStack(spacing: 6) {
                    ForEach(0..<SnowflakeArt.variantCount, id: \.self) { index in
                        Image(nsImage: SnowflakeArt.preview(variant: index)).resizable().frame(width: 34, height: 34)
                    }
                }.accessibilityHidden(true)
            }
            slider("snowflakes.size", value: $store.value.snowflakeSize, range: 0.5...3, step: 0.1, text: "\(Int((store.value.snowflakeSize * 100).rounded()))%")
            SnowRule()
            VStack(alignment: .leading, spacing: 6) {
                Toggle(tr("ui.snow.sweep"), isOn: $store.value.decorativeSweep).toggleStyle(SnowToggleStyle())
                help("ui.snow.sweepHelp")
            }
            VStack(alignment: .leading, spacing: 6) {
                Toggle(tr("tree.grow"), isOn: treeBinding).toggleStyle(SnowToggleStyle())
                    .disabled(store.effectPaused && !store.treeShown)
                help(store.effectPaused ? "tree.paused" : "ui.snow.treeHelp")
            }
        }
    }
    private var wind: some View {
        Group {
            help("wind.help")
            slider("wind.direction", value: $store.value.wind, range: -100...100, text: windText)
            HStack { Text(tr("wind.left")); Spacer(); Text(tr("wind.calm")); Spacer(); Text(tr("wind.right")) }
                .font(.system(size: 12)).foregroundColor(SnowTheme.secondary)
            Button(tr("wind.reset")) { store.value.wind = 0 }.buttonStyle(SnowButtonStyle())
        }
    }
    private var accumulation: some View {
        Group {
            Toggle(tr("accumulation.windows"), isOn: $store.value.accumulateOnWindows)
                .toggleStyle(SnowToggleStyle()).disabled(!store.windowsAvailable)
            slider("accumulation.windowHeight", value: $store.value.windowHeight, range: 4...36,
                   text: "\(Int(store.value.windowHeight)) \(tr("points"))").disabled(!store.value.accumulateOnWindows || !store.windowsAvailable)
            if !store.windowsAvailable { Text(store.windowGeometryMessage).font(.system(size: 12)).foregroundColor(SnowTheme.secondary) }
            SnowRule()
            Toggle(tr("accumulation.bottom"), isOn: $store.value.accumulateAtBottom).toggleStyle(SnowToggleStyle())
            slider("accumulation.bottomHeight", value: $store.value.bottomHeight, range: 8...96,
                   text: "\(Int(store.value.bottomHeight)) \(tr("points"))").disabled(!store.value.accumulateAtBottom)
            SnowRule()
            Toggle(tr("dock.toggle"), isOn: $store.value.accumulateOnDock).toggleStyle(SnowToggleStyle())
            Toggle(tr("ui.dock.vertical"), isOn: $store.value.verticalDock).toggleStyle(SnowToggleStyle()).disabled(!store.value.accumulateOnDock)
            help("ui.dock.heightHelp")
            if store.value.accumulateOnDock { Text(store.dockMessage).font(.system(size: 12)).foregroundColor(SnowTheme.secondary) }
            if SnowAppFeatures.widgetSnow {
                Toggle(tr("widgets.toggle"), isOn: $store.value.accumulateOnWidgets).toggleStyle(SnowToggleStyle())
                Text(store.widgetMessage).font(.system(size: 12)).foregroundColor(SnowTheme.secondary)
            }
        }
    }
    private var play: some View {
        Group {
            HStack(spacing: 8) {
                ForEach(SnowTool.visibleCases, id: \.self) { tool in
                    Button { store.play(with: tool) } label: {
                        VStack(spacing: 12) {
                            SnowToolIcon(tool: tool).font(.system(size: 23, weight: .light))
                            Text(tr("ui.tool." + tool.rawValue)).font(.system(size: 12))
                        }.foregroundColor(store.isToolActive(tool) ? Color(white: 0.12) : .white)
                            .frame(maxWidth: .infinity).frame(height: 77)
                    }.buttonStyle(SnowButtonStyle(selected: store.isToolActive(tool)))
                        .accessibilityLabel(tr("tool." + tool.rawValue))
                        .accessibilityAddTraits(store.isToolActive(tool) ? [.isSelected] : [])
                        .disabled(store.effectPaused || store.effectsHidden)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                title("ui.game.rollTitle"); help("ui.game.rollHelp")
            }
            VStack(alignment: .leading, spacing: 8) {
                title("ui.game.stackTitle"); help("ui.game.stackHelp")
            }
            if store.effectPaused || store.effectsHidden { help("cleaner.paused") }
            HStack(spacing: 10) {
                Text("Esc").font(.system(size: 12, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                Text(tr("ui.game.escape")).font(.system(size: 12)).foregroundColor(SnowTheme.secondary)
            }
        }
    }
    private var cleaner: some View {
        Group {
            field("cleaner.character") {
                SnowSegmented(selection: $store.value.cleaner, choices: CleanerCharacter.allCases.map { ($0, tr("cleaner." + $0.rawValue)) })
            }
            SnowCleanupActions(store: store, emphasizeCleaner: true, showsCleanerHelp: true)
            SnowRule()
            Toggle(tr("cleaner.auto"), isOn: $store.value.automaticCleaner).toggleStyle(SnowToggleStyle())
            help("ui.cleaner.autoHelp")
            if SnowAppFeatures.bladeImages {
                Toggle(tr("cleaner.blade"), isOn: $store.value.useBladeImage).toggleStyle(SnowToggleStyle())
                    .disabled(ImportedAssets.image(for: .blade) == nil)
                ImportImageView(importer: store.importer).id(store.language)
            }
        }
    }
    private var garlands: some View {
        Group {
            field("ui.garland.style") {
                HStack(spacing: 8) {
                    ForEach(GarlandStyle.allCases, id: \.self) { style in
                        Button {
                            store.value.garlandStyle = style
                            if store.value.garland == .off { store.value.garland = .steady }
                        } label: {
                            VStack(spacing: 7) {
                                Image(nsImage: ScreenGarlandRenderer.preview(style: style, palette: store.value.garlandPalette))
                                    .resizable().scaledToFit().frame(height: 44).clipShape(RoundedRectangle(cornerRadius: 7))
                                Text(tr("ui.garland.style." + style.rawValue)).font(.system(size: 11)).lineLimit(1)
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(SnowButtonStyle(selected: store.value.garlandStyle == style, radius: 12))
                            .accessibilityLabel(tr("garland.style." + style.rawValue))
                    }
                }
            }
            field("garland.mode") {
                SnowMenu(title: tr("garland." + store.value.garland.rawValue), identifier: "garland.mode",
                         options: GarlandMode.allCases.map { mode in
                    SnowMenuOption(title: tr("garland." + mode.rawValue), selected: store.value.garland == mode,
                                   action: { store.value.garland = mode })
                }).frame(height: 36).id(store.language)
            }
            field("garland.palette") {
                SnowMenu(title: tr("palette." + store.value.garlandPalette.rawValue), identifier: "garland.palette",
                         options: GarlandPalette.allCases.map { palette in
                    SnowMenuOption(title: tr("palette." + palette.rawValue), selected: store.value.garlandPalette == palette,
                                   action: { store.value.garlandPalette = palette })
                }).frame(height: 36).id(store.language).disabled(store.value.garland == .off)
            }
            SnowRule()
            slider("garland.brightness", value: $store.value.garlandBrightness, range: 0...1, step: 0.01,
                   text: "\(Int((store.value.garlandBrightness * 100).rounded()))%")
            slider("garland.intensity", value: $store.value.garlandBlinkIntensity, range: 0...1, step: 0.01,
                   text: "\(Int((store.value.garlandBlinkIntensity * 100).rounded()))%")
                .disabled((store.value.garland == .off || store.value.garland == .steady) && !store.treeShown)
            help("ui.garland.intensityHelp")
        }
    }
    private var displays: some View {
        Group {
            Toggle(tr("displays.all"), isOn: $store.value.allDisplays).toggleStyle(SnowToggleStyle())
            help("ui.displays.help")
            SnowRule()
            ForEach(store.displayList, id: \.id) { display in
                Toggle(isOn: Binding(get: { store.value.allDisplays || store.value.displayIDs.contains(display.id) }, set: { enabled in
                    if enabled { store.value.displayIDs.insert(display.id) } else { store.value.displayIDs.remove(display.id) }
                })) {
                    Label(display.name, systemImage: "display")
                }.toggleStyle(SnowToggleStyle()).disabled(store.value.allDisplays)
                SnowRule()
            }
            if store.displayList.isEmpty { help("status.noDisplays") }
            help("ui.displays.emptyHelp")
            Label(tr("ui.displays.fullscreenHelp"), systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12)).foregroundColor(SnowTheme.secondary).padding(.top, 22)
        }
    }
    private var performance: some View {
        Group {
            title("ui.quality.mode")
            VStack(spacing: 0) {
                ForEach(SnowQuality.allCases, id: \.self) { quality in
                    Button { store.value.quality = quality } label: {
                        HStack(spacing: 15) {
                            Image(systemName: store.value.quality == quality ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 20)).foregroundColor(SnowTheme.silver)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tr("ui.quality." + quality.rawValue)).font(.system(size: 15, weight: .semibold))
                                Text(tr("ui.quality." + quality.rawValue + ".help")).font(.system(size: 12)).foregroundColor(SnowTheme.secondary)
                            }
                            Spacer(minLength: 0)
                        }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(store.value.quality == quality ? 0.13 : 0))
                    }.buttonStyle(.plain).accessibilityAddTraits(store.value.quality == quality ? [.isSelected] : [])
                    if quality != SnowQuality.allCases.last { SnowRule() }
                }
            }.clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.22), lineWidth: 1))
            help("ui.quality.powerHelp")
            SnowRule()
            Toggle(tr("performance.reduceMotion"), isOn: $store.value.respectReduceMotion).toggleStyle(SnowToggleStyle())
            help("performance.reduceMotion.help")
        }
    }
    private var general: some View {
        Group {
            title("ui.general.startup")
            Toggle(tr("login.toggle"), isOn: Binding(get: { store.loginEnabled }, set: { store.setLoginEnabled($0) })).toggleStyle(SnowToggleStyle())
            Text(store.loginMessage).font(.system(size: 12)).foregroundColor(SnowTheme.secondary)
            Button { store.openLoginSettings() } label: {
                Label(tr("login.settings"), systemImage: "arrow.up.right.square")
            }.buttonStyle(SnowButtonStyle())
            SnowRule().padding(.vertical, 8)
            title("ui.general.defaults")
            help("ui.general.resetHelp")
            Button(tr("reset.button")) { resetConfirmation = true }.buttonStyle(SnowButtonStyle())
            help("ui.general.resetPreserves")
        }
    }
    private var privacy: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("ui.general.local")
            Image(systemName: "snowflake").font(.system(size: 48, weight: .ultraLight)).accessibilityHidden(true)
            help("privacy.body")
            Text("Snow \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · macOS 12+")
                .font(.system(size: 12)).foregroundColor(SnowTheme.secondary)
            Link(destination: URL(string: "https://t.me/Radion013")!) {
                Text(tr("ui.general.creator"))
            }.font(.system(size: 13)).foregroundColor(SnowTheme.secondary)
                .help("https://t.me/Radion013")
        }
    }
    private var treeBinding: Binding<Bool> {
        Binding(get: { store.treeShown }, set: { store.setTreesShown($0) })
    }
    private var windText: String {
        if abs(store.value.wind) < 0.5 { return tr("wind.calm") }
        return "\(Int(abs(store.value.wind))) " + tr(store.value.wind < 0 ? "wind.left" : "wind.right").lowercased()
    }
    private func title(_ key: String) -> some View {
        Text(tr(key)).font(.system(size: 15, weight: .semibold))
    }
    private func help(_ key: String) -> some View {
        Text(tr(key)).font(.system(size: 12)).foregroundColor(SnowTheme.secondary)
            .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
    }
    private func field<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) { title(key); content() }
    }
    private func slider(_ key: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 1, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { title(key); Spacer(); Text(text).monospacedDigit() }
            SnowSlider(value: value, range: range, step: step, valueDescription: text, label: tr(key)).frame(height: 25)
        }
    }
}

/// Local outline artwork, independent of newer system symbol catalogs.
struct SnowCleaningIcon: Shape {
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
