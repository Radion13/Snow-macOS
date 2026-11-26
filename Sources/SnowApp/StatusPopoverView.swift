import SwiftUI

struct StatusPopoverView: View {
    @ObservedObject var store: SettingsStore
    var viewportHeight: CGFloat = SnowPopoverLayout.preferredHeight
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            StatusPopoverContent(store: store)
        }.frame(width: SnowPopoverLayout.designWidth, height: viewportHeight / SnowPopoverLayout.scale)
            .scaleEffect(SnowPopoverLayout.scale, anchor: .topLeading)
            .frame(width: SnowPopoverLayout.width, height: viewportHeight, alignment: .topLeading)
            .background(SnowTheme.background).preferredColorScheme(.dark)
    }
}

private struct StatusPopoverContent: View {
    @ObservedObject var store: SettingsStore
    var body: some View {
        VStack(alignment: .leading, spacing: SnowPopoverLayout.rowSpacing) {
            HStack(spacing: 10) {
                Image(systemName: "snowflake").font(.system(size: 29, weight: .light)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("app.name")).font(.system(size: 20, weight: .semibold))
                    Text(store.statusMessage).font(.system(size: 11)).foregroundColor(SnowTheme.secondary)
                }
                Spacer(minLength: 0)
                SnowPauseButton(store: store)
                Menu {
                    Button(tr(store.effectsHidden ? "menu.show" : "menu.hide")) { store.onToggleHidden?() }
                    Divider()
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Button { store.selectLanguage(language) } label: {
                            if store.language == language { Label(language.name, systemImage: "checkmark") }
                            else { Text(language.name) }
                        }
                    }
                    Divider()
                    Button(tr("menu.quit")) { store.onQuit?() }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 17)).frame(width: 21, height: 28)
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel(tr("ui.more"))
            }.padding(.bottom, SnowPopoverLayout.headerSpacing - SnowPopoverLayout.rowSpacing)
            SnowSegmented(selection: $store.value.weather, choices: SnowWeather.allCases.map { ($0, tr("weather." + $0.rawValue)) })
            SettingsPreview(store: store, compact: true).frame(height: 93).frame(maxWidth: .infinity)
            HStack(spacing: 20) {
                Text(tr("ui.flakes")).fontWeight(.medium)
                Spacer(minLength: 0)
                SnowMenu(title: tr("snowflakes." + store.value.snowflakeStyle.rawValue), identifier: "snowflakes.style",
                         options: SnowflakeStyle.allCases.map { style in
                    SnowMenuOption(title: tr("snowflakes." + style.rawValue), selected: store.value.snowflakeStyle == style,
                                   action: { store.value.snowflakeStyle = style })
                }).frame(width: 155, height: 36).id(store.language)
            }
            VStack(spacing: 4) {
                HStack { Text(tr("ui.size")); Spacer(); Text("\(Int((store.value.snowflakeSize * 100).rounded()))%").monospacedDigit() }
                SnowSlider(value: $store.value.snowflakeSize, range: 0.5...3, step: 0.1, valueDescription: "\(Int((store.value.snowflakeSize * 100).rounded()))%", label: tr("snowflakes.size")).frame(height: 25)
            }
            VStack(spacing: 4) {
                HStack {
                    Text(tr("section.wind")); Spacer()
                    Text(abs(store.value.wind) < 0.5 ? tr("wind.calm") : "\(Int(abs(store.value.wind))) " + tr(store.value.wind < 0 ? "wind.left" : "wind.right").lowercased())
                        .foregroundColor(SnowTheme.secondary).monospacedDigit()
                }
                SnowSlider(value: $store.value.wind, range: -100...100, label: tr("wind.direction")).frame(height: 25)
            }
            sectionRule
            Toggle(tr("ui.quick.trees"), isOn: Binding(get: { store.treeShown }, set: { store.setTreesShown($0) }))
                .toggleStyle(SnowToggleStyle())
                .accessibilityIdentifier("quick.trees")
                .disabled((store.effectPaused || store.effectsHidden) && !store.treeShown)
            sectionRule
            Text(tr("section.cleaner")).foregroundColor(SnowTheme.secondary).font(.system(size: 14, weight: .medium))
            SnowCleanupActions(store: store)
            sectionRule
            Text(tr("ui.playTitle")).foregroundColor(SnowTheme.secondary).font(.system(size: 14, weight: .medium))
            HStack(spacing: 7) {
                ForEach(SnowTool.visibleCases, id: \.self) { tool in
                    Button { store.play(with: tool) } label: {
                        SnowToolIcon(tool: tool).font(.system(size: 23, weight: .light))
                            .foregroundColor(store.isToolActive(tool) ? Color(white: 0.12) : .white)
                            .frame(maxWidth: .infinity).frame(height: 26)
                    }.buttonStyle(SnowButtonStyle(selected: store.isToolActive(tool)))
                        .help(tr("tool." + tool.rawValue))
                        .accessibilityLabel(tr("tool." + tool.rawValue))
                        .accessibilityAddTraits(store.isToolActive(tool) ? [.isSelected] : [])
                        .disabled(store.effectPaused || store.effectsHidden)
                }
            }
            if store.effectPaused || store.effectsHidden { Text(tr("cleaner.paused")).font(.system(size: 11)).foregroundColor(SnowTheme.secondary) }
            sectionRule
            Button { store.onOpenSettings?() } label: {
                HStack(spacing: 11) {
                    Image(systemName: "gearshape").font(.system(size: 20, weight: .light))
                    Text(tr("ui.allSettings")); Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12))
                }.frame(maxWidth: .infinity)
            }.buttonStyle(SnowButtonStyle())
        }.font(.system(size: 14)).foregroundColor(.white)
            .padding(18).frame(maxWidth: .infinity)
            .background(SnowTheme.background)
            .accentColor(SnowTheme.silver).preferredColorScheme(.dark)
            .environment(\.locale, store.language.locale)
    }
    private var sectionRule: some View {
        SnowRule().padding(.vertical, SnowPopoverLayout.dividerSpacing - SnowPopoverLayout.rowSpacing)
    }
}
