import SwiftUI
import UIKit

/// Hosting controller for iPad fullscreen: hides status bar, auto-hides home indicator, ignores safe area margins.
final class FullScreenHostingController<Content: View>: UIHostingController<Content> {

    override var prefersStatusBarHidden: Bool { true }

    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.insetsLayoutMarginsFromSafeArea = false
    }
}
