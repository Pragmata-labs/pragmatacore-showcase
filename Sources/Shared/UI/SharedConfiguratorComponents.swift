import SwiftUI

// MARK: - Bottom Bar
// Exterior: Livery + Equipment cards
// Interior: 4 colour circle buttons

struct BottomConfigurationCards: View {
    var configManager: BoatConfiguratorState
    var focusedCard: FocusState<UUID?>.Binding
    var onInteriorColorSelected: ((InteriorColor) -> Void)?

    var body: some View {
        if configManager.isInteriorEnabled {
            InteriorColorPicker(
                colors: configManager.interiorColors,
                selectedId: configManager.selectedInteriorColor
            ) { color in
                configManager.selectedInteriorColor = color.id
                onInteriorColorSelected?(color)
            }
        } else {
            HStack(spacing: 24) {
                ForEach(configManager.configurations) { option in
                    ConfiguratorCard(
                        option: option,
                        selectedChoice: configManager.selectedChoices[option.id] ?? option.choices.first ?? "",
                        isActive: configManager.activeBottomMenu == option.id,
                        isEnabled: true,
                        focusedCard: focusedCard
                    ) {
                        withAnimation {
                            configManager.activeBottomMenu =
                                (configManager.activeBottomMenu == option.id) ? nil : option.id
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.cardHeight)
            .defaultFocus(focusedCard, configManager.configurations.first?.id)
        }
    }
}

// MARK: - Interior Color Picker
// 4 round buttons, outer 70×70, inner circle 46×46

struct InteriorColorPicker: View {
    let colors: [InteriorColor]
    let selectedId: UUID?
    let onSelect: (InteriorColor) -> Void
    @FocusState private var focusedColor: UUID?

    var body: some View {
        HStack(spacing: 24) {
            ForEach(colors) { color in
                let isFocused = focusedColor == color.id
#if os(tvOS)
                colorLabel(color: color, isFocused: isFocused)
                    .focusable(true)
                    .focused($focusedColor, equals: color.id)
                    .onTapGesture { onSelect(color) }
                    .animation(.easeInOut(duration: AppTheme.focusDuration), value: isFocused)
                    .animation(.easeInOut(duration: AppTheme.toggleDuration), value: selectedId)
#else
                Button { onSelect(color) } label: {
                    colorLabel(color: color, isFocused: isFocused)
                }
                .configuratorButtonStyle()
                .focused($focusedColor, equals: color.id)
                .macHoverOutline(isCircle: true)
                .animation(.easeInOut(duration: AppTheme.focusDuration), value: isFocused)
                .animation(.easeInOut(duration: AppTheme.toggleDuration), value: selectedId)
#endif
            }
        }
#if os(tvOS)
        .focusSection()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focusedColor = colors.first?.id
            }
        }
#endif
        .frame(height: AppTheme.cardHeight)
        .defaultFocus($focusedColor, colors.first?.id)
    }

    private func colorLabel(color: InteriorColor, isFocused: Bool) -> some View {
        ZStack {
            Circle()
                .fill(color.color)
                .frame(width: 46, height: 46)
        }
        .frame(width: 70, height: 70)
        .background(
            Circle()
                .fill(selectedId == color.id ? AppTheme.activeIndicator : AppTheme.barButton)
        )
        .overlay(
            Circle().stroke(
                isFocused ? AppTheme.strokeFocused : (selectedId == color.id ? AppTheme.strokeFocused : AppTheme.strokeDefault),
                lineWidth: isFocused || selectedId == color.id ? 2 : 1
            )
        )
        .scaleEffect(isFocused ? 1.1 : 1.0)
    }
}

// MARK: - Configuration Card

struct ConfiguratorCard: View {
    let option: ConfigurationOption
    let selectedChoice: String
    let isActive: Bool
    let isEnabled: Bool
    var focusedCard: FocusState<UUID?>.Binding
    let onTap: () -> Void

    var body: some View {
        let isFocused = focusedCard.wrappedValue == option.id
#if os(tvOS)
        cardLabel(isFocused: isFocused)
            .focusable(isEnabled)
            .focused(focusedCard, equals: option.id)
            .onTapGesture { if isEnabled { onTap() } }
            .animation(.easeInOut(duration: AppTheme.focusDuration), value: isFocused)
            .animation(.easeInOut(duration: AppTheme.toggleDuration), value: isEnabled)
#else
        Button(action: { if isEnabled { onTap() } }) {
            cardLabel(isFocused: isFocused)
        }
        .configuratorButtonStyle()
        .focused(focusedCard, equals: option.id)
        .macHoverOutline(cornerRadius: 12)
        .animation(.easeInOut(duration: AppTheme.focusDuration), value: isFocused)
        .animation(.easeInOut(duration: AppTheme.toggleDuration), value: isEnabled)
#endif
    }

    private func cardLabel(isFocused: Bool) -> some View {
        VStack(spacing: 4) {
            Text(option.title)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
            Text(selectedChoice)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(width: 200)
        .appGlass(tint: isActive ? AppTheme.activeIndicator : AppTheme.barButton, cornerRadius: 12)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                        lineWidth: isFocused ? 2 : 1)
        )
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .shadow(color: isFocused ? AppTheme.strokeFocused.opacity(0.5) : .clear, radius: 12)
        .opacity(isEnabled ? 1.0 : 0.35)
    }
}

// MARK: - Selection Menu Overlay

struct SelectionMenuOverlay: View {
    let option: ConfigurationOption
    @Binding var selectedChoice: String
    var colorForChoice: ((String) -> Color?)? = nil
    let onDismiss: () -> Void
    @FocusState private var focusedChoice: String?
    @FocusState private var isBackFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                Text("Select \(option.title)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.bottom, 8)

                VStack(spacing: 12) {
                    ForEach(option.choices, id: \.self) { choice in
                        let isChoiceFocused = focusedChoice == choice
                        choiceRow(choice: choice, isChoiceFocused: isChoiceFocused)
#if os(tvOS)
                            .focusable(true)
                            .focused($focusedChoice, equals: choice)
                            .onTapGesture { selectedChoice = choice; onDismiss() }
#else
                            .onTapGesture { selectedChoice = choice; onDismiss() }
                            .configuratorButtonStyle()
                            .focused($focusedChoice, equals: choice)
                            .macHoverOutline(cornerRadius: 15)
#endif
                            .animation(.easeInOut(duration: AppTheme.focusDuration), value: isChoiceFocused)
                    }
                }

                backRow(isFocused: isBackFocused)
#if os(tvOS)
                    .focusable(true)
                    .focused($isBackFocused)
                    .onTapGesture { onDismiss() }
#else
                    .onTapGesture { onDismiss() }
                    .configuratorButtonStyle()
                    .focused($isBackFocused)
                    .macHoverOutline(cornerRadius: 15)
#endif
                    .animation(.easeInOut(duration: AppTheme.focusDuration), value: isBackFocused)
            }
            .padding(32)
            .appGlass(tint: AppTheme.panelBackground, cornerRadius: AppTheme.panelRadius)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.panelRadius))
            .shadow(radius: 20)
        }
#if os(tvOS)
        .focusSection()
#endif
        .onAppear { focusedChoice = selectedChoice }
    }

    private func choiceRow(choice: String, isChoiceFocused: Bool) -> some View {
        HStack {
            if let color = colorForChoice?(choice) {
                Circle().fill(color).frame(width: 14, height: 14)
            }
            Text(choice)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            if choice == selectedChoice {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 384)
        .appGlass(tint: choice == selectedChoice ? AppTheme.selectedTint : AppTheme.rowInactive, cornerRadius: 15)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15)
            .stroke(isChoiceFocused ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                    lineWidth: isChoiceFocused ? 2 : 1))
        .scaleEffect(isChoiceFocused ? 1.02 : 1.0)
        .shadow(color: isChoiceFocused ? AppTheme.strokeFocused.opacity(0.5) : .clear, radius: 10)
    }

    private func backRow(isFocused: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.left").font(.system(size: 18))
            Text("Back").font(.system(size: 18, weight: .medium))
        }
        .foregroundStyle(AppTheme.primaryText)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 384)
        .appGlass(tint: AppTheme.rowInactive, cornerRadius: 15)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15)
            .stroke(isFocused ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                    lineWidth: isFocused ? 2 : 1))
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .shadow(color: isFocused ? AppTheme.strokeFocused.opacity(0.5) : .clear, radius: 10)
    }
}

// MARK: - Settings View

struct ConfiguratorSettingsView: View {
    var pragmataStore: PragmataViewStore
    var onBack: () -> Void

    // Route all engine calls through the platform-native view type.
    // Both PragmataView (iOS/tvOS) and PragmataMacView (macOS) expose the same ObjC interface.
    #if os(macOS)
    private var nativeView: PragmataMacView? { pragmataStore.macView }
    #else
    private var nativeView: PragmataView? { pragmataStore.view }
    #endif

    @State private var ambientOcclusionEnabled: Bool = true
    @State private var bloomEnabled: Bool            = true
    @State private var isLandingGearRetracted: Bool  = false
    @State private var isRearDoorOpen: Bool          = false
    @FocusState private var focusedField: SettingsField?
    @State private var sunLightValue: Double         = 110000
    @State private var ambientLightValue: Double     = 0.33
    #if os(macOS)
    @State private var selectedResolutionPreset: ResolutionPreset = .native
    @State private var selectedAA: AASelection       = .msaa2
    #else
    @State private var selectedResolutionPreset: ResolutionPreset = .half
    @State private var selectedAA: AASelection       = .msaa2
    #endif
    @State private var toneMapperIndex: Int          = 1
    @State private var debugAxisEnabled: Bool        = false

    private enum AASelection: Int { case fxaaOn = 0, fxaaOff, msaa2, msaaOff }

    private enum SettingsField: Hashable {
        case resolutionNative, resolutionHigh, resolutionHalf, resolutionThird
        case fxaaOn, fxaaOff, msaa2, msaaOff
        case aoOn, aoOff
        case bloomOn, bloomOff
        case toneLinear, toneFilmic, toneAces
        case debugAxisOn, debugAxisOff
        case landingGear, rearDoor
        case sunMinus, sunPlus
        case ambientMinus, ambientPlus
        case back
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.bottom, 8)

                settingsSection("Resolution") {
                    HStack(spacing: 12) {
                        optionButton("Native 1.0×", isSelected: selectedResolutionPreset == .native, focus: .resolutionNative) {
                            selectedResolutionPreset = .native
                            nativeView?.setResolutionPreset(.native)
                        }
                        optionButton("High 0.7×", isSelected: selectedResolutionPreset == .high, focus: .resolutionHigh) {
                            selectedResolutionPreset = .high
                            nativeView?.setResolutionPreset(.high)
                        }
                        optionButton("Half 0.5×", isSelected: selectedResolutionPreset == .half, focus: .resolutionHalf) {
                            selectedResolutionPreset = .half
                            nativeView?.setResolutionPreset(.half)
                        }
                        optionButton("Third 0.33×", isSelected: selectedResolutionPreset == .third, focus: .resolutionThird) {
                            selectedResolutionPreset = .third
                            nativeView?.setResolutionPreset(.third)
                        }
                    }
                }

                settingsSection("Anti-Aliasing") {
                    HStack(spacing: 12) {
                        optionButton("FXAA On", isSelected: selectedAA == .fxaaOn, focus: .fxaaOn) {
                            selectedAA = .fxaaOn
                            nativeView?.setAntiAliasingFXAA(true)
                            nativeView?.setAntiAliasingMSAA(false, sampleCount: 1)
                        }
                        optionButton("FXAA Off", isSelected: selectedAA == .fxaaOff, focus: .fxaaOff) {
                            selectedAA = .fxaaOff
                            nativeView?.setAntiAliasingFXAA(false)
                        }
                        optionButton("MSAA 2×", isSelected: selectedAA == .msaa2, focus: .msaa2) {
                            selectedAA = .msaa2
                            nativeView?.setAntiAliasingMSAA(true, sampleCount: 2)
                        }
                        optionButton("MSAA Off", isSelected: selectedAA == .msaaOff, focus: .msaaOff) {
                            selectedAA = .msaaOff
                            nativeView?.setAntiAliasingMSAA(false, sampleCount: 1)
                            nativeView?.setAntiAliasingFXAA(true)
                        }
                    }
                }

                settingsSection("Ambient Occlusion") {
                    HStack(spacing: 12) {
                        optionButton("On", isSelected: ambientOcclusionEnabled, focus: .aoOn) {
                            ambientOcclusionEnabled = true
                            nativeView?.setAmbientOcclusionEnabled(true)
                        }
                        optionButton("Off", isSelected: !ambientOcclusionEnabled, focus: .aoOff) {
                            ambientOcclusionEnabled = false
                            nativeView?.setAmbientOcclusionEnabled(false)
                        }
                    }
                }

                settingsSection("Bloom") {
                    HStack(spacing: 12) {
                        optionButton("On", isSelected: bloomEnabled, focus: .bloomOn) {
                            bloomEnabled = true
                            nativeView?.setBloomEnabled(true)
                        }
                        optionButton("Off", isSelected: !bloomEnabled, focus: .bloomOff) {
                            bloomEnabled = false
                            nativeView?.setBloomEnabled(false)
                        }
                    }
                }

                settingsSection("Tone Mapper") {
                    HStack(spacing: 12) {
                        optionButton("Linear", isSelected: toneMapperIndex == 0, focus: .toneLinear) {
                            toneMapperIndex = 0; nativeView?.setToneMapper(0)
                        }
                        optionButton("Filmic", isSelected: toneMapperIndex == 2, focus: .toneFilmic) {
                            toneMapperIndex = 2; nativeView?.setToneMapper(2)
                        }
                        optionButton("ACES", isSelected: toneMapperIndex == 1, focus: .toneAces) {
                            toneMapperIndex = 1; nativeView?.setToneMapper(1)
                        }
                    }
                }

                settingsSection("Debug Axis") {
                    HStack(spacing: 12) {
                        optionButton("On", isSelected: debugAxisEnabled, focus: .debugAxisOn) {
                            debugAxisEnabled = true
                            nativeView?.setDebugAxisVisible(true)
                        }
                        optionButton("Off", isSelected: !debugAxisEnabled, focus: .debugAxisOff) {
                            debugAxisEnabled = false
                            nativeView?.setDebugAxisVisible(false)
                        }
                    }
                }

                settingsSection("Debug Animations") {
                    HStack(spacing: 12) {
                        optionButton(isLandingGearRetracted ? "LG Retracted" : "LG Extended",
                                     isSelected: isLandingGearRetracted, focus: .landingGear) {
                            isLandingGearRetracted.toggle()
                            let count = Int(nativeView?.getAnimationCount() ?? 0)
                            guard 0 < count else { return }
                            if isLandingGearRetracted {
                                nativeView?.playAnimation(at: 0, action: "play", partName: "")
                            } else {
                                nativeView?.playAnimationReverse(at: 0, action: "reverse", partName: "")
                            }
                        }
                        optionButton(isRearDoorOpen ? "Door Open" : "Door Closed",
                                     isSelected: isRearDoorOpen, focus: .rearDoor) {
                            isRearDoorOpen.toggle()
                            let count = Int(nativeView?.getAnimationCount() ?? 0)
                            guard 1 < count else { return }
                            if isRearDoorOpen {
                                nativeView?.playAnimation(at: 1, action: "play", partName: "")
                            } else {
                                nativeView?.playAnimationReverse(at: 1, action: "reverse", partName: "")
                            }
                        }
                    }
                }

                settingsSection("Sun Light") {
                    HStack(spacing: 16) {
                        lightAdjustButton(icon: "minus.circle.fill", focus: .sunMinus) { adjustSun(-10000) }
                        Text("\(Int(sunLightValue))")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(minWidth: 90, alignment: .center)
                        lightAdjustButton(icon: "plus.circle.fill", focus: .sunPlus) { adjustSun(10000) }
                    }
                    .frame(maxWidth: 400)
                }

                settingsSection("Ambient Light") {
                    HStack(spacing: 16) {
                        lightAdjustButton(icon: "minus.circle.fill", focus: .ambientMinus) { adjustAmbient(-0.1) }
                        Text(String(format: "%.2f", ambientLightValue))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(minWidth: 90, alignment: .center)
                        lightAdjustButton(icon: "plus.circle.fill", focus: .ambientPlus) { adjustAmbient(0.1) }
                    }
                    .frame(maxWidth: 400)
                }

                Button(action: onBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left").font(.system(size: 18))
                        Text("Back").font(.system(size: 18, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .appGlass(tint: AppTheme.rowInactive, cornerRadius: 15)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(focusedField == .back ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                                    lineWidth: focusedField == .back ? 2 : 1)
                    )
                    .scaleEffect(focusedField == .back ? 1.02 : 1.0)
                    .shadow(color: focusedField == .back ? AppTheme.strokeFocused.opacity(0.5) : .clear, radius: 10)
                }
                .configuratorButtonStyle()
                .frame(maxWidth: .infinity)
                .focused($focusedField, equals: .back)
                .animation(.easeInOut(duration: AppTheme.focusDuration), value: focusedField == .back)
            }
            .padding(32)
        }
        .frame(maxWidth: 520, maxHeight: 560)
        .appGlass(tint: AppTheme.panelBackground, cornerRadius: AppTheme.panelRadius)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.panelRadius))
        .shadow(radius: 20)
#if os(tvOS)
        .focusSection()
        .defaultFocus($focusedField, .resolutionNative)
#endif
        .onAppear(perform: loadCurrentSettings)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.labelText)
        content()
    }

    private func optionButton(_ title: String, isSelected: Bool, focus: SettingsField, action: @escaping () -> Void) -> some View {
        let isFocused = focusedField == focus
        let label = Text(title)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .appGlass(tint: isSelected ? AppTheme.selectedTint : AppTheme.rowInactive, cornerRadius: AppTheme.buttonRadius)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonRadius)
                .stroke(isFocused ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                        lineWidth: isFocused ? 2 : 1))
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: isFocused ? AppTheme.strokeFocused.opacity(0.5) : .clear, radius: 10)
#if os(tvOS)
        return label
            .focusable(true)
            .focused($focusedField, equals: focus)
            .onTapGesture { action() }
            .animation(.easeInOut(duration: AppTheme.focusDuration), value: isFocused)
#else
        return Button(action: action) { label }
            .configuratorButtonStyle()
            .focused($focusedField, equals: focus)
            .animation(.easeInOut(duration: AppTheme.focusDuration), value: isFocused)
#endif
    }

    private func lightAdjustButton(icon: String, focus: SettingsField, action: @escaping () -> Void) -> some View {
        let isFocused = focusedField == focus
        let label = Image(systemName: icon)
            .font(.system(size: 28))
            .foregroundStyle(isFocused ? AppTheme.strokeFocused : AppTheme.primaryText)
            .padding(6)
            .clipShape(Circle())
            .overlay(Circle().stroke(isFocused ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                                     lineWidth: isFocused ? 2 : 1))
            .scaleEffect(isFocused ? 1.1 : 1.0)
            .shadow(color: isFocused ? AppTheme.strokeFocused.opacity(0.5) : .clear, radius: 10)
#if os(tvOS)
        return label
            .focusable(true)
            .focused($focusedField, equals: focus)
            .onTapGesture { action() }
            .animation(.easeInOut(duration: AppTheme.focusDuration), value: isFocused)
#else
        return Button(action: action) { label }
            .configuratorButtonStyle()
            .focused($focusedField, equals: focus)
            .animation(.easeInOut(duration: AppTheme.focusDuration), value: isFocused)
#endif
    }

    private func adjustSun(_ delta: Double) {
        sunLightValue = min(200000, max(0, sunLightValue + delta))
        nativeView?.setSunLightIntensity(Float(sunLightValue))
    }

    private func adjustAmbient(_ delta: Double) {
        ambientLightValue = min(1, max(0, ambientLightValue + delta))
        nativeView?.setAmbientLightIntensity(Float(ambientLightValue))
    }

    private func loadCurrentSettings() {
        guard let view = nativeView else { return }
        sunLightValue           = Double(view.getSunLightIntensity())
        ambientLightValue       = Double(view.getAmbientLightIntensity())
        ambientOcclusionEnabled = view.getAmbientOcclusionEnabled()
        toneMapperIndex         = Int(view.getToneMapper())
        debugAxisEnabled        = view.isDebugAxisVisible()
        let scale = view.getCurrentResolutionScale()
        if scale >= 0.99      { selectedResolutionPreset = .native }
        else if scale >= 0.65 { selectedResolutionPreset = .high }
        else if scale >= 0.4  { selectedResolutionPreset = .half }
        else                  { selectedResolutionPreset = .third }
        let aaType = view.getAntiAliasingType()
        if aaType == 0      { selectedAA = .fxaaOff }
        else if aaType == 2 { selectedAA = .msaa2 }
        else                { selectedAA = .fxaaOn }
    }
}
