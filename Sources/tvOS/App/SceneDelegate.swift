/**
 * @file SceneDelegate.swift
 * @brief Handles scene-level lifecycle events for the application.
 *
 * This class manages window attachment, background/foreground transitions,
 * and scene disconnection.
 */

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    /** The main window of the application. */
    var window: UIWindow?

    /**
     * Called when a new scene is being added to the app.
     * 
     * @param scene The scene object being connected.
     * @param session The session object associated with the scene.
     * @param connectionOptions Options for configuring the scene.
     */
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let pragmataStore = PragmataViewStore()

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(
            rootView: TVOSMainView(pragmataStore: pragmataStore)
        )
        self.window = window
        window.makeKeyAndVisible()
    }

    /**
     * Called when the scene is being released by the system.
     */
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    /**
     * Called when the scene has moved from an inactive state to an active state.
     */
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    /**
     * Called when the scene will move from an active state to an inactive state.
     */
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    /**
     * Called as the scene transitions from the background to the foreground.
     */
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    /**
     * Called as the scene transitions from the foreground to the background.
     */
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}
