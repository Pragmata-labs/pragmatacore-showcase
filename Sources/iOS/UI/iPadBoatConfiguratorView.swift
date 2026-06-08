import SwiftUI

struct iPadBoatConfiguratorView: View {
    @State var pragmataStore: PragmataViewStore

    @State private var configManager = BoatConfiguratorState()
    @State private var orbitManager = OrbitState()
    @State private var isMenuOpen = false
    @State private var isSettingsOpen = false
    @State private var hasSetInitialResolution = false
    @State private var lastDragTranslation: CGSize = .zero
    @State private var lastPinchScale: CGFloat = 1.0
    @FocusState private var focusedConfigCard: UUID?

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
        .onAppear(perform: setupOnAppear)
        .onChange(of: pragmataStore.isLoaded) { _, v in onLoadedChanged(v) }
        .onChange(of: orbitManager.isEnabled) { _, v in onOrbitChanged(v) }
        .onChange(of: orbitManager.zoomLevel) { old, new in onZoomChanged(oldLevel: old, newLevel: new) }
        .onChange(of: configManager.selectedCamera) { _, v in onCameraChanged(v) }
        .onChange(of: configManager.selectedEnvironment) { _, v in onEnvironmentChanged(v) }
        .onChange(of: configManager.selectedChoices) { old, new in updateConfiguration(oldChoices: old, newChoices: new) }
        .environment(configManager)
        .environment(orbitManager)
        .ignoresSafeArea()
    }

    private var backgroundLayer: some View {
        PragmataViewRepresentable(store: pragmataStore)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard orbitManager.isEnabled else { return }
                        let sensitivity: Float = 0.15
                        let dx = Float(value.translation.width - lastDragTranslation.width) * sensitivity / 100
                        let dy = Float(-(value.translation.height - lastDragTranslation.height)) * sensitivity / 100
                        lastDragTranslation = value.translation
                        pragmataStore.view?.applyOrbitRotationDeltaX(dx, deltaY: dy)
                    }
                    .onEnded { _ in lastDragTranslation = .zero }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { scale in
                        guard orbitManager.isEnabled else { return }
                        let delta = -Float(scale - lastPinchScale) * 4
                        lastPinchScale = scale
                        pragmataStore.view?.applyOrbitZoom(delta)
                    }
                    .onEnded { _ in lastPinchScale = 1.0 }
            )
            .allowsHitTesting(orbitManager.isEnabled)
    }

    private var sidebarsLayer: some View {
        HStack(spacing: 0) {
            iOSLeftSideMenu(selectedCamera: $configManager.selectedCamera)
                .frame(width: 96)
                .environment(orbitManager)

            Spacer()

            iOSRightSideMenu(
                currentZoom: $orbitManager.zoomLevel,
                onOrbitTap: { orbitManager.toggle() },
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
            .environment(orbitManager)
            .environment(configManager)
        }
        .frame(maxHeight: .infinity)
        .padding(screenMargin)
    }

    private var controlsLayer: some View {
        VStack(spacing: 0) {
            iOSTopBarView(
                selectedEnvironment: $configManager.selectedEnvironment,
                onMenuTap: { isMenuOpen = true }
            )
            .environment(orbitManager)

            Spacer()

            BottomConfigurationCards(
                configManager: configManager,
                focusedCard: $focusedConfigCard,
                onInteriorColorSelected: { color in
                    applyInteriorColor(color)
                }
            )
            .padding(.horizontal, 64)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(screenMargin)
        .allowsHitTesting(true)
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
                    withAnimation(.easeOut(duration: 0.2)) { configManager.activeBottomMenu = nil }
                }
            )
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
                        isSettingsOpen = false
                    }
                } else {
                    VStack(spacing: 24) {
                        Text("Menu")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.bottom, 8)

                        Button { isSettingsOpen = true } label: {
                            menuRow(icon: "gearshape.fill", text: "Settings")
                        }
                        .buttonStyle(.configurator)

                        Button {
                            pragmataStore.view?.inspectMaterials()
                            isMenuOpen = false
                        } label: {
                            menuRow(icon: "magnifyingglass", text: "Inspect Materials")
                        }
                        .buttonStyle(.configurator)

                        Button { isMenuOpen = false } label: {
                            menuRow(icon: "xmark", text: "Close")
                        }
                        .buttonStyle(.configurator)
                    }
                    .padding(32)
                    .appGlass(tint: AppTheme.panelBackground, cornerRadius: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .shadow(radius: 20)
                }
            }
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

    private func menuRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 18))
            Text(text).font(.system(size: 18, weight: .medium))
            Spacer()
        }
        .foregroundStyle(AppTheme.primaryText)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: 320)
        .appGlass(tint: AppTheme.rowInactive, cornerRadius: 15)
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }

    private func onLoadedChanged(_ isLoaded: Bool) {
        guard isLoaded else { return }
        if orbitManager.isIPad {
            pragmataStore.view?.setOrbitEnabled(true)
            let zoomOffset = pragmataStore.view?.getIPadZoomOffset() ?? 10.0
            pragmataStore.view?.applyOrbitZoom(zoomOffset)
        }
        if let equip = configManager.configurations.first(where: { $0.title == "Equipment" }),
           let choice = configManager.selectedChoices[equip.id] {
            applyConfiguration(choice: choice, for: "Equipment")
        }
    }
    private func onOrbitChanged(_ isOn: Bool) {
        pragmataStore.view?.setOrbitEnabled(isOn)
        if isOn { configManager.activeBottomMenu = nil }
    }
    private func onZoomChanged(oldLevel: Int, newLevel: Int) {
        pragmataStore.view?.applyOrbitZoom(Float(newLevel - oldLevel) * 5.0)
    }
    private func onEnvironmentChanged(_ env: EnvironmentOption) {
        configManager.isEnvironmentTransitioning = true
        pragmataStore.view?.switchSceneEnvironment(env.bridgeName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            configManager.isEnvironmentTransitioning = false
        }
    }
    private func setupOnAppear() {
        orbitManager.initializeForDevice()
        pragmataStore.view?.loadModel(named: "PCraft400", withPreset: nil)
        applyConfiguration(choice: "Golden", for: "Livery")
        applyConfiguration(choice: "Base", for: "Equipment")

        DispatchQueue.main.async {
            guard !hasSetInitialResolution, let view = pragmataStore.view else { return }
            view.setResolutionPreset(.high)
            hasSetInitialResolution = true
        }
    }

    private func onCameraChanged(_ newCamera: ECameraPreset) { ConfiguratorViewLogic.updateCamera(newCamera, view: pragmataStore.view) }

    private func updateConfiguration(oldChoices: [UUID: String], newChoices: [UUID: String]) {
        ConfiguratorViewLogic.updateConfiguration(oldChoices: oldChoices, newChoices: newChoices,
                                                  configManager: configManager, view: pragmataStore.view)
    }

    private func applyConfiguration(choice: String, for category: String) {
        ConfiguratorViewLogic.applyConfiguration(choice: choice, for: category,
                                                 configManager: configManager, view: pragmataStore.view)
    }

    private func applyInteriorColor(_ color: InteriorColor) {
        AppLog.log("Configurator", "🎨 Interior color: \(color.name)")
        pragmataStore.view?.applyLeatherColor(color.name)
        configManager.selectedInteriorColor = color.id
    }
}
