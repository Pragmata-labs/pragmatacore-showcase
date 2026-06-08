import SwiftUI

// MARK: - Design tokens — single source of truth for colours, sizes, radii

enum AppTheme {
    // MARK: Backgrounds
    static let panelBackground = Color.black.opacity(0.85)
    static let rowInactive     = Color.black.opacity(0.5)
    static let barButton       = Color.black.opacity(0.6)
    static let activeIndicator = Color.white.opacity(0.85)
    static let subtleIndicator = Color.white.opacity(0.08)
    static let selectedTint    = Color.white.opacity(0.25)
    static let activeTint      = Color.white.opacity(0.40)

    // MARK: Text
    static let primaryText   = Color.white
    static let secondaryText = Color.white.opacity(0.7)
    static let labelText     = Color.white.opacity(0.9)

    // MARK: Borders
    static let strokeFocused = Color(hex: "FFD200")
    static let strokeDefault = Color.white.opacity(0.15)

    // MARK: Corner radii
    static let buttonRadius: CGFloat = 10
    static let cardRadius: CGFloat   = 20
    static let panelRadius: CGFloat  = 30
    static let circleRadius: CGFloat = 40

    // MARK: Sizes
    static let sideButtonSize: CGFloat = 80
    static let cardHeight: CGFloat     = 96
    static let logoHeight: CGFloat     = 64

    // MARK: Animation durations
    static let focusDuration:  Double = 0.2
    static let toggleDuration: Double = 0.25
}

// MARK: - Solid background modifier — replaces ultraThinMaterial (perf)

extension View {
    func appGlass(tint: Color = .clear, cornerRadius: CGFloat = AppTheme.buttonRadius) -> some View {
        self.background(tint, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Platform-adaptive button style

extension View {
    @ViewBuilder
    func configuratorButtonStyle() -> some View {
#if os(tvOS)
        self.buttonStyle(.plain).focusEffectDisabled()
#else
        self.buttonStyle(.configurator)
#endif
    }
}

// MARK: - macOS hover yellow outline modifier

#if os(macOS)
private struct MacHoverOutlineModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isCircle: Bool
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .focusable(false)
            .overlay {
                if isCircle {
                    Circle()
                        .stroke(hovered ? AppTheme.strokeFocused : .clear, lineWidth: 2)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(hovered ? AppTheme.strokeFocused : .clear, lineWidth: 2)
                }
            }
            .scaleEffect(hovered ? 1.05 : 1.0)
            .shadow(color: hovered ? AppTheme.strokeFocused.opacity(0.4) : .clear, radius: 10)
            .onHover { hovered = $0 }
            .animation(.easeInOut(duration: 0.15), value: hovered)
    }
}
#endif

extension View {
    @ViewBuilder
    func macHoverOutline(cornerRadius: CGFloat = AppTheme.buttonRadius, isCircle: Bool = false) -> some View {
#if os(macOS)
        modifier(MacHoverOutlineModifier(cornerRadius: cornerRadius, isCircle: isCircle))
#else
        self
#endif
    }
}

// MARK: - iOS press-scale button style (tvOS uses system .card)

struct ConfiguratorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                Color.white
                    .opacity(configuration.isPressed ? 0.18 : 0)
                    .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == ConfiguratorButtonStyle {
    static var configurator: ConfiguratorButtonStyle { .init() }
}

// MARK: - Color hex initializer (shared, used by ConfiguratorModels)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
