import Foundation

// Shared protocol bridging PragmataView (iOS/tvOS) and PragmataMacView (macOS)
// so ConfiguratorViewLogic and PragmataViewStore work platform-agnostically.
protocol ConfiguratorEngineView: AnyObject {
    // Configurator
    func applyHullColor(_ colorName: String)
    func applySeatColor(_ colorName: String)
    func applyDeckTexture(_ styleName: String)
    func applyWoodTexture(_ woodName: String)
    func applyEquipmentPackage(_ packageName: String)
    func applyLeatherColor(_ colorName: String)
    func applyLivery(_ index: Int)

    // Scene
    func setSceneEnvironment(_ environment: String)
    func switchSceneEnvironment(_ environment: String)
    func setShipState(_ state: String)
    func setInteriorMode(_ entering: Bool)
    func switchSceneMode(_ mode: String)

    // Camera presets
    func moveToPresetFront()
    func moveToPresetTop()
    func moveToPresetRear()
    func moveToPresetSide()
    func moveToPresetInterior()

    // Render
    func setNightMode(_ enabled: Bool)
    func setBloomEnabled(_ enabled: Bool)
    func setAmbientOcclusionEnabled(_ enabled: Bool)
}

#if os(macOS)
extension PragmataMacView: ConfiguratorEngineView {}
#else
extension PragmataView: ConfiguratorEngineView {}
#endif
