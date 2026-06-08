import SwiftUI

// Shared models in Shared/UI/ConfiguratorModels.swift
// Theme tokens in Shared/UI/AppTheme.swift
// Shared components in Shared/UI/SharedConfiguratorComponents.swift

// MARK: - Top Bar (iOS)
// Logo | Hangar / Seaside / Space | Menu

struct iOSTopBarView: View {
    @Binding var selectedEnvironment: EnvironmentOption
    @Environment(OrbitState.self) private var orbitManager
    @Environment(BoatConfiguratorState.self) private var configManager
    var onMenuTap: () -> Void

    private var shouldHideUI: Bool { orbitManager.isEnabled && !orbitManager.isIPad }

    var body: some View {
        HStack(spacing: 0) {
            if !shouldHideUI {
                Image("NavalLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: AppTheme.logoHeight)
                    .focusable(false)
                    .transition(.opacity)
            }

            Spacer()

            if !shouldHideUI {
                HStack(spacing: 8) {
                    ForEach(EnvironmentOption.allCases, id: \.rawValue) { env in
                        let isDisabled = configManager.isInteriorEnabled || configManager.isEnvironmentTransitioning
                        Button { selectedEnvironment = env } label: {
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
                                .opacity(isDisabled ? 0.35 : 1.0)
                        }
                        .buttonStyle(.configurator)
                        .disabled(isDisabled)
                        .animation(.easeInOut(duration: AppTheme.toggleDuration), value: isDisabled)
                    }
                }
                .transition(.opacity)
            }

            Spacer()

            if !shouldHideUI {
                Button(action: onMenuTap) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 48, height: 48)
                        .appGlass(tint: AppTheme.barButton, cornerRadius: 24)
                        .clipShape(Circle())
                }
                .buttonStyle(.configurator)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: AppTheme.toggleDuration), value: orbitManager.isEnabled)
    }
}

// MARK: - Left Side Menu (iOS)
// Camera preset buttons: Front / Side / Rear / Top

struct iOSLeftSideMenu: View {
    @Binding var selectedCamera: ECameraPreset
    @Environment(OrbitState.self) private var orbitManager

    private let cameraOptions: [ECameraPreset] = [.front, .side, .rear, .top]
    private var shouldHideUI: Bool { orbitManager.isEnabled && !orbitManager.isIPad }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            if !shouldHideUI {
                ForEach(cameraOptions, id: \.id) { cam in
                    iOSSideMenuButton(
                        isActive: selectedCamera == cam,
                        label: cam.title,
                        rounded: true,
                        action: { selectedCamera = cam }
                    )
                }
            }
            Spacer(minLength: 16)
        }
        .animation(.easeInOut(duration: AppTheme.toggleDuration), value: orbitManager.isEnabled)
    }
}

// MARK: - Right Side Menu (iOS)
// Interior/Exterior | Orbit

struct iOSRightSideMenu: View {
    @Environment(OrbitState.self) private var orbitManager
    @Environment(BoatConfiguratorState.self) private var configManager
    @Binding var currentZoom: Int
    var onOrbitTap: (() -> Void)?
    var onInteriorTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Interior/Exterior toggle
            iOSSideMenuButton(
                isActive: configManager.isInteriorEnabled,
                icon: configManager.isInteriorEnabled ? "sofa.fill" : "sailboat",
                action: { onInteriorTap?() }
            )

            // Orbit — hidden on iPad (always on)
            if !orbitManager.isIPad {
                iOSSideMenuButton(
                    isActive: orbitManager.isEnabled,
                    icon: orbitManager.isEnabled ? "rotate.3d.fill" : "rotate.3d",
                    action: { onOrbitTap?() }
                )
            }

            Spacer(minLength: 16)
        }
        .animation(.easeInOut(duration: AppTheme.toggleDuration), value: configManager.isInteriorEnabled)
    }
}

// MARK: - Side Menu Button (iOS)

struct iOSSideMenuButton: View {
    let isActive: Bool
    var icon: String? = nil
    var label: String? = nil
    var rounded: Bool = false  // true = rounded square (camera labels), false = circle (icon)
    let action: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Group {
                if let icon {
                    // Always circle — background, clip and border must all use Circle()
                    // so there are no stray corners showing through the glass tint.
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(isActive ? Color.black : AppTheme.secondaryText)
                        .frame(width: AppTheme.sideButtonSize, height: AppTheme.sideButtonSize)
                        .background(isActive ? AppTheme.activeIndicator : AppTheme.barButton, in: Circle())
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(
                                isFocused ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                                lineWidth: isFocused ? 2 : 1
                            )
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
                            RoundedRectangle(cornerRadius: AppTheme.buttonRadius).stroke(
                                isFocused ? AppTheme.strokeFocused : AppTheme.strokeDefault,
                                lineWidth: isFocused ? 2 : 1
                            )
                        )
                }
            }
            .scaleEffect(isFocused ? 1.1 : 1.0)
        }
        .buttonStyle(.configurator)
        .animation(.easeInOut(duration: AppTheme.focusDuration), value: isFocused)
        .focusable(true)
        .focused($isFocused)
    }
}
