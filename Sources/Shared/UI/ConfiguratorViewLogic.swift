import Foundation

// Shared configurator logic — platform-agnostic via ConfiguratorEngineView protocol.
@MainActor
enum ConfiguratorViewLogic {

    static func colorKeyForChoice(_ choice: String) -> String {
        choice.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    static func applyConfiguration(choice: String, for category: String,
                                    configManager: BoatConfiguratorState,
                                    view: (any ConfiguratorEngineView)?) {
        let key = colorKeyForChoice(choice)
        switch category {
        case "Livery":
            let idx = configManager.liveryIndex(for: choice)
            view?.applyLivery(idx)
            AppLog.log("Configurator", "🎨 Livery: \(choice) → index \(idx)")
        case "Equipment":
            view?.applyEquipmentPackage(key)
            AppLog.log("Configurator", "🎨 Equipment: \(choice) (\(key))")
        case "Hull":
            view?.applyHullColor(key)
            AppLog.log("Configurator", "🎨 Hull: \(choice) (\(key))")
        case "Seats":
            view?.applySeatColor(key)
            AppLog.log("Configurator", "🎨 Seats: \(choice) (\(key))")
        case "Deck":
            view?.applyDeckTexture(key)
            AppLog.log("Configurator", "🎨 Deck: \(choice) (\(key))")
        case "Wood":
            view?.applyWoodTexture(key)
            AppLog.log("Configurator", "🎨 Wood: \(choice) (\(key))")
        default:
            AppLog.log("Configurator", "⚠️ Unknown category: \(category)")
        }
    }

    static func updateConfiguration(oldChoices: [UUID: String], newChoices: [UUID: String],
                                     configManager: BoatConfiguratorState,
                                     view: (any ConfiguratorEngineView)?) {
        for option in configManager.configurations {
            let oldChoice = oldChoices[option.id]
            let newChoice = newChoices[option.id]
            if oldChoice != newChoice, let choice = newChoice {
                applyConfiguration(choice: choice, for: option.title,
                                   configManager: configManager, view: view)
            }
        }
    }

    static func updateCamera(_ camera: ECameraPreset, view: (any ConfiguratorEngineView)?) {
        switch camera {
        case .front:    view?.moveToPresetFront()
        case .side:     view?.moveToPresetSide()
        case .rear:     view?.moveToPresetRear()
        case .top:      view?.moveToPresetTop()
        case .interior: view?.moveToPresetInterior()
        }
    }
}
