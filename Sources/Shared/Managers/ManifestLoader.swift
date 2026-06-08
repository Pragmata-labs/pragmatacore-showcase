/**
 * @file ManifestLoader.swift
 * @brief Utility for loading and parsing model manifest JSON files.
 *
 * This module provides functions to retrieve model configuration,
 * visual settings, animations, and color schemes from bundled JSON assets.
 * It serves as a bridge layer for future Core3D ManifestReader integration.
 */

import Foundation

// MARK: - Manifest Models

/**
 * @struct ModelManifest
 * @brief Root model for a model configuration manifest.
 */
struct ModelManifest: Codable {
    let vin: String
    let model: String
    let label: String
    let color: String
    let rimType: String
    let privacyGlass: Bool
    let spoiler: Bool
    let paths: ModelPaths
    let animations: AnimationConfig
    /** List of button IDs that should be visible for this model */
    let topViewButtons: [String]?  // Simplified: just list of visible button IDs
    
    enum CodingKeys: String, CodingKey {
        case vin, model, label, color, rimType, privacyGlass, spoiler, paths, animations, topViewButtons
    }
}

/**
 * @struct ModelPaths
 * @brief Defines the filesystem paths for model components.
 */
struct ModelPaths: Codable {
    let body: String
    let rims: String
    let spoiler: String
}

/**
 * @struct AnimationConfig
 * @brief Configuration for initial and state-based animations.
 */
struct AnimationConfig: Codable {
    let initial: AnimationInitial?
    let states: AnimationStates?
}

/**
 * @struct AnimationInitial
 * @brief Initial animation to play upon model load.
 */
struct AnimationInitial: Codable {
    let name: String
    let frame: Int
}

/**
 * @struct AnimationStates
 * @brief Defines animation sequences for specific environment or interaction states.
 */
struct AnimationStates: Codable {
    let sunny: [AnimationState]?
    let rainStart: [AnimationState]?
    let rainStop: [AnimationState]?
    let doorOpen: AnimationState?
    let doorClose: AnimationState?
}

/**
 * @struct AnimationState
 * @brief Details for a specific animation state.
 */
struct AnimationState: Codable {
    let name: String
    let reverse: Bool?
    let loop: Bool?
}

// Simplified - JSON now only contains list of visible button IDs
// Layout, labels, animations are hardcoded in ViewController

// MARK: - Manifest Loader

/**
 * @class ManifestLoader
 * @brief Singleton class responsible for loading and parsing manifests and color sets.
 */
class ManifestLoader {

    static let shared = ManifestLoader()
    private static let decoder = JSONDecoder()

    private init() {}

    private var cachedHullColorsManifest: HullColorsManifest?
    
    // MARK: - Model Name to VIN Mapping
    
    private let modelToVIN: [String: String] = [
        "PCraft400": "BOAT_D28_001"
    ]
    
    // MARK: - Load Manifest
    
    /**
     * Loads a model manifest by model name.
     * 
     * @param modelName The internal name of the 3D model.
     * @return A ModelManifest object if found and parsed successfully, otherwise nil.
     */
    func loadManifest(forModelName modelName: String) -> ModelManifest? {
        guard let vin = modelToVIN[modelName] else {
            AppLog.log("ManifestLoader", "⚠️ No VIN mapping for model: %@", modelName)
            return nil
        }
        
        return loadManifest(vin: vin)
    }
    
    /**
     * Loads a model manifest by VIN.
     * 
     * @param vin The unique vehicle identification number.
     * @return A ModelManifest object if found and parsed successfully, otherwise nil.
     */
    func loadManifest(vin: String) -> ModelManifest? {
        var jsonPath: String?
        if let path = Bundle.main.path(forResource: vin, ofType: "json", inDirectory: "Catalog") {
            jsonPath = path
        } else if let path = Bundle.main.path(forResource: vin, ofType: "json") {
            jsonPath = path
        }

        guard let jsonPath = jsonPath else {
            AppLog.log("ManifestLoader", "⚠️ Manifest not found for VIN: %@", vin)
            return nil
        }
        
        guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)) else {
            AppLog.log("ManifestLoader", "⚠️ Failed to read manifest data for VIN: %@", vin)
            return nil
        }
        
        do {
            let manifest = try Self.decoder.decode(ModelManifest.self, from: jsonData)
            AppLog.log("ManifestLoader", "✅ Loaded manifest for VIN: %@ (model: %@)", vin, manifest.label)
            return manifest
        } catch {
            AppLog.log("ManifestLoader", "❌ Failed to decode manifest for VIN: %@, error: %@", vin, error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Get Visible Button IDs
    
    /**
     * Retrieves the IDs of UI buttons that should be displayed for a specific car model.
     * 
     * @param modelName The internal name of the 3D model.
     * @return An array of button identity strings.
     */
    func getVisibleButtonIds(forModelName modelName: String) -> [String] {
        guard let manifest = loadManifest(forModelName: modelName) else {
            return []
        }
        
        // Return just the list of button IDs that should be visible
        return manifest.topViewButtons ?? []
    }
    
    // MARK: - Load Hull Colors

    /**
     * @struct HullColor
     * @brief Defines a color with its ID, name, and various color space representations.
     */
    struct HullColor: Codable {
        let id: String
        let hex: String
        let rgb: RGBColor
        let hsl: HSLColor
        let name: String
    }
    
    /**
     * @struct RGBColor
     * @brief Simple Red, Green, Blue color model.
     */
    struct RGBColor: Codable {
        let r: Double
        let g: Double
        let b: Double
    }
    
    /**
     * @struct HSLColor
     * @brief Simple Hue, Saturation, Lightness color model.
     */
    struct HSLColor: Codable {
        let h: Double
        let s: Double
        let l: Double
    }
    
    /**
     * @struct HullColorsManifest
     * @brief Container for hull colors and background environment colors.
     */
    struct HullColorsManifest: Codable {
        let hullColors: [HullColor]?
        let backgroundColors: [HullColor]?
    }

    /**
     * Shared helper to load the color configuration JSON file.
     *
     * @return A HullColorsManifest object if found and parsed successfully, otherwise nil.
     */
    private func loadHullColorsManifest() -> HullColorsManifest? {
        if let cached = cachedHullColorsManifest { return cached }

        var jsonPath: String?
        if let path = Bundle.main.path(forResource: "hull_colors", ofType: "json", inDirectory: "Catalog") {
            jsonPath = path
        } else if let path = Bundle.main.path(forResource: "hull_colors", ofType: "json") {
            jsonPath = path
        }

        guard let jsonPath else {
            AppLog.log("ManifestLoader", "⚠️ hull_colors.json not found")
            return nil
        }
        guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)) else {
            AppLog.log("ManifestLoader", "⚠️ Failed to read hull_colors.json")
            return nil
        }
        do {
            let manifest = try Self.decoder.decode(HullColorsManifest.self, from: jsonData)
            cachedHullColorsManifest = manifest
            return manifest
        } catch {
            AppLog.log("ManifestLoader", "❌ Failed to decode hull_colors.json, error: %@", error.localizedDescription)
            return nil
        }
    }

    /**
     * Retrieves all available hull colors.
     *
     * @return An array of HullColor objects.
     */
    func loadHullColors() -> [HullColor] {
        guard let manifest = loadHullColorsManifest() else {
            return []
        }
        AppLog.log("ManifestLoader", "✅ Loaded %d hull colors", manifest.hullColors?.count ?? 0)
        return manifest.hullColors ?? []
    }

    /**
     * Retrieves all available background environment colors.
     *
     * @return An array of HullColor objects.
     */
    func loadBackgroundColors() -> [HullColor] {
        guard let manifest = loadHullColorsManifest() else {
            return []
        }
        AppLog.log("ManifestLoader", "✅ Loaded %d background colors", manifest.backgroundColors?.count ?? 0)
        return manifest.backgroundColors ?? []
    }
}

