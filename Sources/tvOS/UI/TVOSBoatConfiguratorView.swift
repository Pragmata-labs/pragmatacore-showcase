import SwiftUI

struct TVOSBoatConfiguratorView: View {
    @State var pragmataStore: PragmataViewStore

    @State private var configManager = BoatConfiguratorState()
    @State private var orbitManager = OrbitState()
    @State private var touchPanel = TouchPanelObserver()
    @State private var isMenuOpen = false
    @State private var isSettingsOpen = false
    @State private var hasSetInitialResolution = false
    @State private var menuDefaultFocus: MenuItem = .settings
    @State private var lastFocusedCard: UUID?
    @FocusState private var focusedConfigCard: UUID?
    @FocusState private var isOrbitFocused: Bool
    @FocusState private var menuFocusedItem: MenuItem?

    private enum MenuItem: Hashable { case settings, close }

    private let screenMargin: CGFloat = 32


    var body: some View {
        ZStack {
            backgroundLayer
            sidebarsLayer
            controlsLayer
            overlayLayer
            menuOverlay
            loadingOverlay
        }
        .animation(.easeOut(duration: 0.4), value: pragmataStore.isLoaded)
        .onPlayPauseCommand { orbitManager.toggle() }
        .onExitCommand(perform: onExitCommand)
        .onAppear(perform: setupOnAppear)
        .onChange(of: pragmataStore.isLoaded) { _, v in onLoadedChanged(v) }
        .onChange(of: isMenuOpen) { _, open in onMenuOpenChanged(open) }
        .onChange(of: orbitManager.isEnabled) { _, isOn in onOrbitChanged(isOn) }
        .onChange(of: touchPanel.updateCount) { _, _ in handleTouchRotation(x: touchPanel.x, y: touchPanel.y) }
        .onChange(of: orbitManager.zoomLevel) { oldLevel, newLevel in onZoomChanged(oldLevel: oldLevel, newLevel: newLevel) }
        .onChange(of: configManager.selectedCamera) { _, v in updateCamera(v) }
        .onChange(of: configManager.selectedEnvironment) { _, v in onEnvironmentChanged(v) }
        .onChange(of: configManager.selectedChoices) { old, new in updateConfiguration(oldChoices: old, newChoices: new) }
        .onChange(of: focusedConfigCard) { _, id in if let id { lastFocusedCard = id } }
        .onChange(of: configManager.isInteriorEnabled) { _, isInterior in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                focusedConfigCard = isInterior
                    ? configManager.interiorColors.first?.id
                    : configManager.configurations.first?.id
            }
        }
        .environment(configManager)
        .ignoresSafeArea()
    }

    // MARK: - Layers

    private var backgroundLayer: some View {
        PragmataViewRepresentable(store: pragmataStore)
            .ignoresSafeArea()
            .focusable(orbitManager.isEnabled)
            .focused($isOrbitFocused)
            .onMoveCommand { direction in
                guard orbitManager.isEnabled else { return }
                switch direction {
                case .up:   orbitManager.zoomIn()
                case .down: orbitManager.zoomOut()
                default: break
                }
            }
    }

    private var sidebarsLayer: some View {
        HStack(spacing: 0) {
            LeftSideMenu(selectedCamera: $configManager.selectedCamera)
                .frame(width: 96)
                .focusSection()
                .environment(orbitManager)

            Spacer()

            RightSideMenu(
                currentZoom: $orbitManager.zoomLevel,
                onInteriorTap: {
                    configManager.isInteriorEnabled.toggle()
                    pragmataStore.view?.notifyUserInput()
                    let entering = configManager.isInteriorEnabled
                    pragmataStore.view?.switchSceneMode(entering ? "interior" : "exterior")
                    pragmataStore.view?.setInteriorMode(entering)
                    if !entering, let equip = configManager.configurations.first(where: { $0.title == "Equipment" }),
                       let choice = configManager.selectedChoices[equip.id] {
                        pragmataStore.view?.applyEquipmentPackage(ConfiguratorViewLogic.colorKeyForChoice(choice))
                    }
                }
            )
            .frame(width: 96)
            .focusSection()
            .environment(orbitManager)
            .environment(configManager)
        }
        .frame(maxHeight: .infinity)
        .padding(screenMargin)
    }

    private var controlsLayer: some View {
        VStack(spacing: 0) {
            TopBarView(
                selectedEnvironment: $configManager.selectedEnvironment,
                onMenuTap: { isMenuOpen = true }
            )
            .focusSection()
            .environment(orbitManager)

            Spacer()

            if orbitManager.isEnabled {
                Text("You are in orbit mode. Use ⏯ or ‹ to exit.")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .appGlass(tint: AppTheme.barButton, cornerRadius: AppTheme.buttonRadius)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonRadius)
                        .stroke(AppTheme.strokeDefault, lineWidth: 1))
                    .padding(.bottom, 16)
            } else {
                BottomConfigurationCards(
                    configManager: configManager,
                    focusedCard: $focusedConfigCard,
                    onInteriorColorSelected: { color in
                        AppLog.log("Configurator", "🎨 Interior color: \(color.name)")
                        pragmataStore.view?.applyLeatherColor(color.name)
                        configManager.selectedInteriorColor = color.id
                    }
                )
                .focusSection()
                .padding(.horizontal, 64)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: orbitManager.isEnabled)
        .padding(screenMargin)
    }

    @ViewBuilder
    private var overlayLayer: some View {
        if let activeMenuId = configManager.activeBottomMenu,
           let option = configManager.configurations.first(where: { $0.id == activeMenuId }) {
            SelectionMenuOverlay(
                option: option,
                selectedChoice: Binding(
                    get: { configManager.selectedChoices[activeMenuId] ?? option.choices.first ?? "" },
                    set: { configManager.selectedChoices[activeMenuId] = $0 }
                ),
                colorForChoice: option.title == "Livery" ? { configManager.liveryColor(for: $0) } : nil,
                onDismiss: {
                    focusedConfigCard = activeMenuId
                    withAnimation(.easeOut(duration: 0.2)) { configManager.activeBottomMenu = nil }
                }
            )
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if !pragmataStore.isLoaded {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 32) {
                    Image("NavalLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                    ProgressView(value: Double(pragmataStore.loadingProgress), total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .frame(width: 400)
                    Text(pragmataStore.loadingStage)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var menuOverlay: some View {
        if isMenuOpen {
            ZStack {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { isMenuOpen = false }

                if isSettingsOpen {
                    ConfiguratorSettingsView(pragmataStore: pragmataStore) {
                        menuDefaultFocus = .settings
                        isSettingsOpen = false
                        menuFocusedItem = .settings
                    }
                } else {
                    VStack(spacing: 24) {
                        Text("Menu")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.bottom, 8)

                        menuRow(icon: "gearshape.fill", text: "Settings", isFocused: menuFocusedItem == .settings)
                            .focusable(true)
                            .focused($menuFocusedItem, equals: .settings)
                            .onTapGesture { isSettingsOpen = true }

                        menuRow(icon: "xmark", text: "Close", isFocused: menuFocusedItem == .close)
                            .focusable(true)
                            .focused($menuFocusedItem, equals: .close)
                            .onTapGesture { isMenuOpen = false }
                    }
                    .padding(32)
                    .appGlass(tint: AppTheme.panelBackground, cornerRadius: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(AppTheme.strokeDefault, lineWidth: 1))
                    .shadow(radius: 20)
                    .defaultFocus($menuFocusedItem, menuDefaultFocus)
                }
            }
            .focusSection()
            .transition(.opacity)
        }
    }

    // MARK: - Helpers

    private func onExitCommand() {
        if isSettingsOpen { isSettingsOpen = false }
        else if isMenuOpen { isMenuOpen = false }
        else if orbitManager.isEnabled { orbitManager.toggle() }
        else if configManager.activeBottomMenu != nil {
            withAnimation(.easeOut(duration: 0.2)) { configManager.activeBottomMenu = nil }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedConfigCard = lastFocusedCard ?? configManager.configurations.first?.id
            }
        }
    }

    private func onMenuOpenChanged(_ open: Bool) {
        menuFocusedItem = open ? .settings : nil
        if open { menuDefaultFocus = .settings }
    }

    private func onZoomChanged(oldLevel: Int, newLevel: Int) {
        pragmataStore.view?.applyOrbitZoom(Float(newLevel - oldLevel) * 5.0)
    }

    private func menuRow(icon: String, text: String, isFocused: Bool = false) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 18))
            Text(text).font(.system(size: 18, weight: .medium))
            Spacer()
        }
        .foregroundStyle(AppTheme.primaryText)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: 300)
        .appGlass(tint: AppTheme.barButton, cornerRadius: 15)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(isFocused ? AppTheme.strokeFocused : AppTheme.strokeDefault, lineWidth: isFocused ? 2 : 1))
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .shadow(color: isFocused ? AppTheme.strokeFocused.opacity(0.4) : .clear, radius: 10)
        .animation(.easeInOut(duration: AppTheme.focusDuration), value: isFocused)
    }

    private func setupOnAppear() {
        touchPanel.onZoomIn = { orbitManager.zoomIn() }
        touchPanel.onZoomOut = { orbitManager.zoomOut() }

        pragmataStore.view?.loadModel(named: "PCraft400", withPreset: nil)
        applyConfiguration(choice: "Golden", for: "Livery")
        applyConfiguration(choice: "Base", for: "Equipment")

        DispatchQueue.main.async {
            guard !hasSetInitialResolution, let view = pragmataStore.view else { return }
            let scale = UIScreen.main.nativeScale
            view.setResolutionPreset(scale >= 2.0 ? .half : .native)
            hasSetInitialResolution = true
        }
    }

    private func onOrbitChanged(_ isOn: Bool) {
        pragmataStore.view?.setOrbitEnabled(isOn)
        if isOn {
            configManager.activeBottomMenu = nil
            isOrbitFocused = true
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedConfigCard = lastFocusedCard ?? configManager.configurations.first?.id
            }
        }
    }

    private func onEnvironmentChanged(_ env: EnvironmentOption) {
        configManager.isEnvironmentTransitioning = true
        pragmataStore.view?.switchSceneEnvironment(env.bridgeName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            configManager.isEnvironmentTransitioning = false
        }
    }

    private func onLoadedChanged(_ isLoaded: Bool) {
        guard isLoaded else { return }
        pragmataStore.view?.setBloomEnabled(true)
        if let equip = configManager.configurations.first(where: { $0.title == "Equipment" }),
           let choice = configManager.selectedChoices[equip.id] {
            applyConfiguration(choice: choice, for: "Equipment")
        }
    }

    private func updateConfiguration(oldChoices: [UUID: String], newChoices: [UUID: String]) {
        ConfiguratorViewLogic.updateConfiguration(oldChoices: oldChoices, newChoices: newChoices,
                                                  configManager: configManager, view: pragmataStore.view)
    }

    private func handleTouchRotation(x: Float, y: Float) {
        guard orbitManager.isEnabled else { return }
        let sensitivity: Float = 0.1
        if abs(x) > abs(y) {
            pragmataStore.view?.applyOrbitRotationDeltaX(x * sensitivity, deltaY: 0)
        } else {
            pragmataStore.view?.applyOrbitRotationDeltaX(0, deltaY: y * sensitivity)
        }
    }

    private func updateCamera(_ camera: ECameraPreset) {
        ConfiguratorViewLogic.updateCamera(camera, view: pragmataStore.view)
    }

    private func applyConfiguration(choice: String, for category: String) {
        ConfiguratorViewLogic.applyConfiguration(choice: choice, for: category,
                                                 configManager: configManager, view: pragmataStore.view)
    }
}
