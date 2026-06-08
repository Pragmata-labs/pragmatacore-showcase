import SwiftUI

// MARK: - ECameraPreset

enum ECameraPreset: String, CaseIterable, Identifiable {
    case front    = "Front"
    case side     = "Side"
    case rear     = "Rear"
    case top      = "Top"
    case interior = "Interior"

    var id: String { rawValue }
    var title: String { rawValue }
}

// MARK: - EnvironmentOption

enum EnvironmentOption: String, CaseIterable {
    case hangar  = "Hangar"
    case seaside = "Seaside"
    case space   = "Space"

    var bridgeName: String {
        switch self {
        case .hangar:  return "Hangar"
        case .seaside: return "Seaside"
        case .space:   return "Space"
        }
    }
}

// MARK: - ConfigurationOption

struct ConfigurationOption: Identifiable {
    let id = UUID()
    let title: String
    let choices: [String]
}

// MARK: - InteriorColor

struct InteriorColor: Identifiable {
    let id = UUID()
    let name: String
    let hex: String
    var color: Color { Color(hex: hex) }
}

// MARK: - OrbitState

@MainActor @Observable
final class OrbitState {
    var isEnabled  = false
    var zoomLevel: Int = 0
#if os(macOS)
    var isIPad: Bool { true }   // macOS always-on orbit, same as iPad
#else
    var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
#endif

    private var lastToggleTime: Date = .distantPast

    func toggle() {
        if isIPad {
            AppLog.log("Orbit", "toggle ignored (iPad always has orbit)")
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastToggleTime) > 0.5 else {
            AppLog.log("Orbit", "toggle ignored (debounce)")
            return
        }
        lastToggleTime = now
        isEnabled.toggle()
        if !isEnabled { zoomLevel = 0 }
        AppLog.log("Orbit", "toggled: \(isEnabled ? "ON" : "OFF")")
    }

    func initializeForDevice() {
        if isIPad {
            isEnabled = true
            AppLog.log("Orbit", "iPad detected — orbit always enabled")
        }
    }

    func zoomIn() {
        guard isEnabled else { return }
        zoomLevel = min(3, zoomLevel + 1)
        logZoom()
    }

    func zoomOut() {
        guard isEnabled else { return }
        zoomLevel = max(-3, zoomLevel - 1)
        logZoom()
    }

    private func logZoom() {
        if zoomLevel > 0      { AppLog.log("Zoom", "in +\(zoomLevel)") }
        else if zoomLevel < 0 { AppLog.log("Zoom", "out \(zoomLevel)") }
        else                  { AppLog.log("Zoom", "default (0)") }
    }
}

// MARK: - BoatConfiguratorState

@MainActor @Observable
final class BoatConfiguratorState {
    var selectedCamera: ECameraPreset        = .front
    var selectedEnvironment: EnvironmentOption = .hangar
    var isInteriorEnabled: Bool           = false
    var isEnvironmentTransitioning: Bool  = false
    var isLandingGearRetracted: Bool      = false
    var isRearDoorOpen: Bool              = false

    var configurations: [ConfigurationOption] = [
        ConfigurationOption(title: "Livery",     choices: ["Militech", "Expo", "On Brand", "Golden", "Deep Patrol", "Cammo"]),
        ConfigurationOption(title: "Equipment",  choices: ["Base", "Patrol", "Navy"])
    ]
    var selectedChoices: [UUID: String] = [:]
    var activeBottomMenu: UUID? = nil

    let interiorColors: [InteriorColor] = [
        InteriorColor(name: "Beige",   hex: "DBD3B5"),
        InteriorColor(name: "Navy",    hex: "4A4F61"),
        InteriorColor(name: "Cognac",  hex: "8B4513"),
        InteriorColor(name: "Wine",    hex: "6B1F2A")
    ]
    var selectedInteriorColor: UUID? = nil

    init() {
        if let livery = configurations.first(where: { $0.title == "Livery" }) {
            selectedChoices[livery.id] = "Golden"
        }
        if let equip = configurations.first(where: { $0.title == "Equipment" }) {
            selectedChoices[equip.id] = "Base"
        }
    }

    /// Vraca 1-based index livery-a za bridge (livery.ini [Livery1]…[Livery6])
    func liveryIndex(for name: String) -> Int {
        let choices = configurations.first(where: { $0.title == "Livery" })?.choices ?? []
        return (choices.firstIndex(of: name) ?? 0) + 1
    }

    /// Boja krugica za livery selector — primary za 1–4, secondary za 5–6 (teksture)
    func liveryColor(for name: String) -> Color? {
        switch name {
        case "Militech":    return Color(.sRGB, red: 0.024, green: 0.322, blue: 0.000)
        case "Expo":        return Color(.sRGB, red: 0.302, green: 0.110, blue: 0.443)
        case "On Brand":    return Color(.sRGB, red: 0.533, green: 0.051, blue: 0.114)
        case "Golden":      return Color(.sRGB, red: 0.624, green: 0.427, blue: 0.035)
        case "Deep Patrol": return Color(.sRGB, red: 0.620, green: 0.216, blue: 0.004)
        case "Cammo":       return Color(.sRGB, red: 0.745, green: 1.000, blue: 0.357)
        default:            return nil
        }
    }

}

