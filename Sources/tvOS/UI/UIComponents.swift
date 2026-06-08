import SwiftUI

// MARK: - Top Bar (tvOS)
// Logo | Hangar / Seaside / Space | Menu

struct TopBarView: View {
    @Binding var selectedEnvironment: EnvironmentOption
    @Environment(OrbitState.self) private var orbitManager
    @Environment(BoatConfiguratorState.self) private var configManager
    var onMenuTap: () -> Void
    @FocusState private var focusedEnv: EnvironmentOption?
    @FocusState private var isMenuFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            if !orbitManager.isEnabled {
                Image("NavalLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: AppTheme.logoHeight)
                    .focusable(false)
                    .transition(.opacity)
            }

            Spacer()

            if !orbitManager.isEnabled {
                HStack(spacing: 12) {
                    ForEach(EnvironmentOption.allCases, id: \.rawValue) { env in
                        let isDisabled = configManager.isInteriorEnabled || configManager.isEnvironmentTransitioning
                        let isFocused = focusedEnv == env
                        Text(env.rawValue)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(selectedEnvironment == env ? Color.black : AppTheme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .frame(maxWidth: 100)
                            .appGlass(
                                tint: selectedEnvironment == env ? AppTheme.activeIndicator : AppTheme.barButton,
                                cornerRadius: 12
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isFocused ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                                            lineWidth: isFocused ? 2 : 1)
                            )
                            .scaleEffect(isFocused ? 1.1 : 1.0)
                            .shadow(color: isFocused ? AppTheme.strokeFocused.opacity(0.5) : .clear, radius: 12)
                            .opacity(isDisabled ? 0.35 : 1.0)
                            .focusable(!isDisabled)
                            .focused($focusedEnv, equals: env)
                            .onTapGesture { if !isDisabled { selectedEnvironment = env } }
                            .animation(.easeInOut(duration: AppTheme.focusDuration), value: isFocused)
                            .animation(.easeInOut(duration: AppTheme.toggleDuration), value: isDisabled)
                    }
                }
                .transition(.opacity)
            }

            Spacer()

            if !orbitManager.isEnabled {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 48, height: 48)
                    .appGlass(tint: AppTheme.barButton, cornerRadius: 24)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(isMenuFocused ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                                             lineWidth: isMenuFocused ? 2 : 1))
                    .scaleEffect(isMenuFocused ? 1.15 : 1.0)
                    .focusable(true)
                    .focused($isMenuFocused)
                    .onTapGesture { onMenuTap() }
                    .animation(.easeInOut(duration: AppTheme.focusDuration), value: isMenuFocused)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: AppTheme.toggleDuration), value: orbitManager.isEnabled)
    }
}

// MARK: - Left Side Menu (tvOS)
// Camera buttons: Front / Side / Rear / Top (rounded squares)

struct LeftSideMenu: View {
    @Binding var selectedCamera: ECameraPreset
    @Environment(OrbitState.self) private var orbitManager
    @FocusState private var focusedCamera: ECameraPreset?

    private let cameraOptions: [ECameraPreset] = [.front, .side, .rear, .top]

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            if !orbitManager.isEnabled {
                ForEach(cameraOptions, id: \.id) { cam in
                    SideMenuButton(
                        isActive: selectedCamera == cam,
                        label: cam.title,
                        rounded: true,
                        action: { selectedCamera = cam }
                    )
                    .focused($focusedCamera, equals: cam)
                }
            }
            Spacer(minLength: 16)
        }
        .defaultFocus($focusedCamera, .front)
        .animation(.easeInOut(duration: AppTheme.toggleDuration), value: orbitManager.isEnabled)
    }
}

// MARK: - Right Side Menu (tvOS)
// Interior/Exterior | Orbit indicator (visual only — toggled by ⏯)

struct RightSideMenu: View {
    @Environment(OrbitState.self) private var orbitManager
    @Environment(BoatConfiguratorState.self) private var configManager
    @Binding var currentZoom: Int
    var onInteriorTap: (() -> Void)?
    @FocusState private var focusedButton: RightButton?

    private enum RightButton: Hashable { case interior }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Interior/Exterior
            SideMenuButton(
                isActive: configManager.isInteriorEnabled,
                icon: configManager.isInteriorEnabled ? "sofa.fill" : "sailboat",
                action: { onInteriorTap?() }
            )
            .focused($focusedButton, equals: .interior)

            // Orbit — visual indicator only, ⏯ toggles
            ZStack {
                Image(systemName: orbitManager.isEnabled ? "rotate.3d.fill" : "rotate.3d")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .opacity(orbitManager.isEnabled ? 1.0 : 0.6)
            }
            .frame(width: AppTheme.sideButtonSize, height: AppTheme.sideButtonSize)
            .appGlass(tint: orbitManager.isEnabled ? AppTheme.activeIndicator : .clear,
                      cornerRadius: AppTheme.circleRadius)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.strokeDefault, lineWidth: 1))
            .animation(.easeInOut(duration: AppTheme.toggleDuration), value: orbitManager.isEnabled)

            Spacer(minLength: 16)
        }
    }
}

// MARK: - Side Menu Button (tvOS)

struct SideMenuButton: View {
    let isActive: Bool
    var icon: String? = nil
    var label: String? = nil
    var rounded: Bool = false  // true = rounded square (camera), false = circle (icon)
    let action: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if let icon {
                // Always circle — background, clip and border all use Circle()
                // to avoid corners showing through the glass tint.
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isActive ? Color.black : AppTheme.secondaryText)
                    .frame(width: AppTheme.sideButtonSize, height: AppTheme.sideButtonSize)
                    .background(isActive ? AppTheme.activeIndicator : AppTheme.barButton, in: Circle())
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isFocused ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                                    lineWidth: isFocused ? 2 : 1)
                    )
            } else if let label {
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isActive ? Color.black : AppTheme.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .frame(maxWidth: 100)
                    .appGlass(tint: isActive ? AppTheme.activeIndicator : AppTheme.barButton, cornerRadius: AppTheme.buttonRadius)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.buttonRadius)
                            .stroke(isFocused ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                                    lineWidth: isFocused ? 2 : 1)
                    )
            }
        }
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .shadow(color: isFocused ? AppTheme.strokeFocused.opacity(0.5) : .clear, radius: 12)
        .animation(.easeInOut(duration: AppTheme.focusDuration), value: isFocused)
        .focusable(true)
        .focused($isFocused)
        .onTapGesture { action() }
    }
}
