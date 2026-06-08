import SwiftUI
import AppKit

// MARK: - NSViewRepresentable

struct PragmataMacViewRepresentable: NSViewRepresentable {
    var store: PragmataViewStore

    func makeNSView(context: Context) -> PragmataMacView {
        let view = PragmataMacView()
        store.macView = view
        view.loadingProgressCallback = { [weak store] progress, stage in
            guard let store else { return }
            DispatchQueue.main.async {
                store.loadingProgress = progress
                store.loadingStage    = stage
                if progress >= 1.0 { store.isLoaded = true }
            }
        }
        return view
    }

    func updateNSView(_ nsView: PragmataMacView, context: Context) {}
}

// MARK: - Root view (mirrors iPadBoatConfiguratorView)

struct MacConfiguratorView: View {
    @State var store           = PragmataViewStore()
    @State var configManager   = BoatConfiguratorState()
    @State var orbitManager    = OrbitState()
    @State var isMenuOpen      = false
    @State var isSettingsOpen  = false
    @FocusState private var focusedCard: UUID?

    @State private var lastDragTranslation: CGSize = .zero
    @State private var lastPinchScale: CGFloat     = 1.0

    private let margin: CGFloat = 28

    var body: some View {
        ZStack {
            backgroundLayer
            sidebarsLayer
            controlsLayer
            overlayLayer
            menuOverlay
            loadingOverlay
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.4),  value: store.isLoaded)
        .onAppear(perform: setupOnAppear)
        .onChange(of: store.isLoaded)                    { _, v in onLoadedChanged(v) }
        .onChange(of: orbitManager.zoomLevel)            { old, new in onZoomChanged(oldLevel: old, newLevel: new) }
        .onChange(of: configManager.selectedCamera)      { _, v in updateCamera(v) }
        .onChange(of: configManager.selectedEnvironment) { _, v in
            configManager.isEnvironmentTransitioning = true
            store.macView?.switchSceneEnvironment(v.bridgeName)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                configManager.isEnvironmentTransitioning = false
            }
        }
        .onChange(of: configManager.selectedChoices)     { old, new in updateConfiguration(oldChoices: old, newChoices: new) }
        .environment(configManager)
        .environment(orbitManager)
    }

    // MARK: - Layers

    private var backgroundLayer: some View {
        PragmataMacViewRepresentable(store: store)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        let sensitivity: Float = 0.15
                        let dx = Float(value.translation.width  - lastDragTranslation.width)  * sensitivity / 100
                        let dy = Float(-(value.translation.height - lastDragTranslation.height)) * sensitivity / 100
                        lastDragTranslation = value.translation
                        store.macView?.applyOrbitRotationDeltaX(dx, deltaY: dy)
                    }
                    .onEnded { _ in lastDragTranslation = .zero }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { scale in
                        let delta = -Float(scale - lastPinchScale) * 4
                        lastPinchScale = scale
                        store.macView?.applyOrbitZoom(delta)
                    }
                    .onEnded { _ in lastPinchScale = 1.0 }
            )
    }

    private var sidebarsLayer: some View {
        HStack(spacing: 0) {
            MacLeftSideMenu(selectedCamera: $configManager.selectedCamera)
                .frame(width: 96)
                .environment(orbitManager)

            Spacer()

            MacRightSideMenu(
                onInteriorTap: {
                    configManager.isInteriorEnabled.toggle()
                    let entering = configManager.isInteriorEnabled
                    store.macView?.switchSceneMode(entering ? "interior" : "exterior")
                    store.macView?.setInteriorMode(entering)
                    if !entering,
                       let equip = configManager.configurations.first(where: { $0.title == "Equipment" }),
                       let choice = configManager.selectedChoices[equip.id] {
                        store.macView?.applyEquipmentPackage(ConfiguratorViewLogic.colorKeyForChoice(choice))
                    }
                }
            )
            .frame(width: 96)
            .environment(orbitManager)
            .environment(configManager)
        }
        .frame(maxHeight: .infinity)
        .padding(margin)
    }

    private var controlsLayer: some View {
        VStack(spacing: 0) {
            MacTopBarView(
                selectedEnvironment: $configManager.selectedEnvironment,
                onMenuTap: { isMenuOpen = true }
            )
            .environment(orbitManager)

            Spacer()

            BottomConfigurationCards(
                configManager: configManager,
                focusedCard: $focusedCard,
                onInteriorColorSelected: { color in
                    store.macView?.applyLeatherColor(color.name)
                    configManager.selectedInteriorColor = color.id
                }
            )
            .padding(.horizontal, 64)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(margin)
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
    private var loadingOverlay: some View {
        if !store.isLoaded {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 32) {
                    Image("NavalLogo")
                        .resizable().scaledToFit()
                        .frame(width: 180, height: 180)
                    ProgressView(value: Double(store.loadingProgress), total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .frame(width: 380)
                    Text(store.loadingStage)
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
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture { isMenuOpen = false }

                if isSettingsOpen {
                    ConfiguratorSettingsView(pragmataStore: store) {
                        isSettingsOpen = false
                    }
                } else {
                    VStack(spacing: 24) {
                        Text("Menu")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.bottom, 8)

                        macMenuRow(icon: "gearshape.fill", text: "Settings") { isSettingsOpen = true }
                        macMenuRow(icon: "xmark",          text: "Close")    { isMenuOpen = false }
                        macMenuRow(icon: "power",          text: "Quit")     { NSApp.terminate(nil) }
                            .keyboardShortcut("q", modifiers: .command)
                    }
                    .padding(32)
                    .appGlass(tint: AppTheme.panelBackground, cornerRadius: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(AppTheme.strokeDefault, lineWidth: 1))
                    .shadow(radius: 20)
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: - Logic

    private func setupOnAppear() {
        DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
        orbitManager.isEnabled = true
        ConfiguratorViewLogic.applyConfiguration(choice: "Golden", for: "Livery",
                                                  configManager: configManager, view: store.engineView)
        ConfiguratorViewLogic.applyConfiguration(choice: "Base",   for: "Equipment",
                                                  configManager: configManager, view: store.engineView)
    }

    private func onLoadedChanged(_ loaded: Bool) {
        guard loaded else { return }
        store.macView?.setOrbitEnabled(true)
        let zoomOffset = store.macView?.getIPadZoomOffset() ?? 10.0
        store.macView?.applyOrbitZoom(zoomOffset)

        // macOS: native resolution (Retina display — no need to scale down,
        // and dynamic res changes + bloom + Metal can trigger blit size mismatch artifacts).
        store.macView?.setResolutionPreset(.native)

        // macOS: MSAA 2x (splotch bug resolved by setClearOptions fix)
        store.macView?.setAntiAliasingFXAA(false)
        store.macView?.setAntiAliasingMSAA(true, sampleCount: 2)

        store.macView?.setBloomEnabled(true)
        store.macView?.setBloomStrength(0.3, levels: 2, quality: 0)
        store.macView?.setAmbientOcclusionEnabled(false)
        if let equip = configManager.configurations.first(where: { $0.title == "Equipment" }),
           let choice = configManager.selectedChoices[equip.id] {
            ConfiguratorViewLogic.applyConfiguration(choice: choice, for: "Equipment",
                                                      configManager: configManager, view: store.engineView)
        }
    }

    private func updateCamera(_ cam: ECameraPreset) {
        ConfiguratorViewLogic.updateCamera(cam, view: store.engineView)
    }

    private func onZoomChanged(oldLevel: Int, newLevel: Int) {
        store.macView?.applyOrbitZoom(Float(newLevel - oldLevel) * 5.0)
    }

    private func updateConfiguration(oldChoices: [UUID: String], newChoices: [UUID: String]) {
        ConfiguratorViewLogic.updateConfiguration(oldChoices: oldChoices, newChoices: newChoices,
                                                   configManager: configManager, view: store.engineView)
    }

    private func macMenuRow(icon: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).font(.system(size: 18))
                Text(text).font(.system(size: 18, weight: .medium))
                Spacer()
            }
            .foregroundStyle(AppTheme.primaryText)
            .padding(.horizontal, 24).padding(.vertical, 16)
            .frame(width: 300)
            .appGlass(tint: AppTheme.barButton, cornerRadius: 15)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(AppTheme.strokeDefault, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .macHoverOutline(cornerRadius: 15)
    }
}

// MARK: - Top Bar

struct MacTopBarView: View {
    @Binding var selectedEnvironment: EnvironmentOption
    @Environment(OrbitState.self) private var orbitManager
    @Environment(BoatConfiguratorState.self) private var configManager
    var onMenuTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Image("NavalLogo")
                .resizable().aspectRatio(contentMode: .fit)
                .frame(height: AppTheme.logoHeight)

            Spacer()

            HStack(spacing: 8) {
                ForEach(EnvironmentOption.allCases, id: \.rawValue) { env in
                    let isDisabled = configManager.isInteriorEnabled || configManager.isEnvironmentTransitioning
                    Button { selectedEnvironment = env } label: {
                        Text(env.rawValue)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(selectedEnvironment == env ? Color.black : AppTheme.primaryText)
                            .padding(.horizontal, 12).padding(.vertical, 16)
                            .frame(maxWidth: 100)
                            .appGlass(
                                tint: selectedEnvironment == env ? AppTheme.activeIndicator : AppTheme.barButton,
                                cornerRadius: 12
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .opacity(isDisabled ? 0.35 : 1.0)
                    }
                    .buttonStyle(.configurator)
                    .macHoverOutline(cornerRadius: 12)
                    .disabled(isDisabled)
                    .animation(.easeInOut(duration: AppTheme.toggleDuration), value: isDisabled)
                }
            }

            Spacer()

            Button(action: onMenuTap) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 48, height: 48)
                    .appGlass(tint: AppTheme.barButton, cornerRadius: 24)
                    .clipShape(Circle())
            }
            .buttonStyle(.configurator)
            .macHoverOutline(isCircle: true)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Left Side Menu

struct MacLeftSideMenu: View {
    @Binding var selectedCamera: ECameraPreset
    @Environment(OrbitState.self) private var orbitManager
    private let cams: [ECameraPreset] = [.front, .side, .rear, .top]

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            ForEach(cams, id: \.id) { cam in
                MacSideButton(label: cam.title, isActive: selectedCamera == cam) {
                    selectedCamera = cam
                }
            }
            Spacer(minLength: 16)
        }
    }
}

// MARK: - Right Side Menu

struct MacRightSideMenu: View {
    @Environment(OrbitState.self) private var orbitManager
    @Environment(BoatConfiguratorState.self) private var configManager
    var onInteriorTap: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            MacSideButton(
                icon: configManager.isInteriorEnabled ? "sofa.fill" : "sailboat",
                isActive: configManager.isInteriorEnabled,
                action: onInteriorTap
            )
            Spacer(minLength: 16)
        }
    }
}

// MARK: - Mac side button (hover-based, mirrors tvOS SideMenuButton)

struct MacSideButton: View {
    var icon: String?  = nil
    var label: String? = nil
    let isActive: Bool
    let action: () -> Void
    @State private var hovered = false

    private let size: CGFloat = 48

    var body: some View {
        Button(action: action) {
            Group {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(isActive ? Color.black : AppTheme.secondaryText)
                        .frame(width: size, height: size)
                        .background(isActive ? AppTheme.activeIndicator : AppTheme.barButton, in: Circle())
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(hovered ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                                        lineWidth: hovered ? 2 : 1)
                        )
                } else if let label {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isActive ? Color.black : AppTheme.secondaryText)
                        .frame(width: size * 2, height: size)
                        .appGlass(tint: isActive ? AppTheme.activeIndicator : AppTheme.barButton, cornerRadius: AppTheme.buttonRadius)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.buttonRadius)
                                .stroke(hovered ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                                        lineWidth: hovered ? 2 : 1)
                        )
                }
            }
            .scaleEffect(hovered ? 1.06 : 1.0)
            .shadow(color: hovered ? AppTheme.strokeFocused.opacity(0.4) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: hovered)
    }
}
