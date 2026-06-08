import SwiftUI
#if !os(macOS)
import UIKit
#endif
import Observation

// Shared by tvOS (Siri Remote: touch surface, Play/Pause, focus) and iPad (touch only: drag to rotate, tap orbit to toggle, no remote).

/// Holds the underlying PragmataView so SwiftUI can drive it (camera, colors, etc.).
@Observable
final class PragmataViewStore {
#if os(macOS)
    weak var macView: PragmataMacView?
#else
    weak var view: PragmataView?
#endif
    var engineView: (any ConfiguratorEngineView)? {
        #if os(macOS)
        return macView
        #else
        return view
        #endif
    }

    var loadingProgress: Float = 0.0
    var loadingStage: String = "Initializing..."
    var isLoaded: Bool = false

    func handleSignal(type: String, message: String) {}
}

#if !os(macOS)
/// SwiftUI wrapper for the Filament 3D view. Creates a PragmataView (same as tvOS).
struct PragmataViewRepresentable: UIViewRepresentable {
    var store: PragmataViewStore

    func makeUIView(context: Context) -> PragmataView {
        let v = PragmataView(frame: .zero)
        store.view = v

        v.loadingProgressCallback = { [weak store] progress, stage in
            guard let store else { return }
            DispatchQueue.main.async {
                store.loadingProgress = progress
                store.loadingStage = stage
                if progress >= 1.0 {
                    store.isLoaded = true
                }
            }
        }

        return v
    }

    func updateUIView(_ uiView: PragmataView, context: Context) {}
}
#endif
