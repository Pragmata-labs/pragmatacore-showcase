/**
 * @file AppDelegate.swift
 * @brief The main entry point and app delegate for the configurator application.
 *
 * This class handles application-level lifecycle events and scene configuration.
 */

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    /**
     * Called when the application has finished launching.
     *
     * @param application The singleton application object.
     * @param launchOptions A dictionary indicating the reason the app was launched (if any).
     * @return Boolean indicating whether the launch process completed successfully.
     */
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    // MARK: UISceneSession Lifecycle

    /**
     * Returns the configuration to use when creating a new scene session.
     *
     * @param application The singleton application object.
     * @param connectingSceneSession The session object being created.
     * @param options Relevant information about the scene being created.
     * @return The scene configuration to be used.
     */
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    /**
     * Called when the user discards one or more scene sessions.
     *
     * @param application The singleton application object.
     * @param sceneSessions A set of scene session objects that were discarded.
     */
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

