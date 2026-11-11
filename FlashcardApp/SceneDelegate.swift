//
//  SceneDelegate.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import GoogleSignIn
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if connectionOptions.notificationResponse?.notification.request.identifier == DailyStudyReminder.identifier {
            DailyStudyReminder.requestOpenReview()
        }
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        // The Settings choice is persisted; apply it from the first frame, not only while Settings is used.
        window?.overrideUserInterfaceStyle = AppearanceOption.resolve(UserDefaultsPreferences.shared.appearance).userInterfaceStyle
        let initialViewController = BaseNavigationController()
        let startUpWireFrame = StartUpWireframe()
        initialViewController.setRootWireframe(startUpWireFrame)
        window?.rootViewController = initialViewController
        window?.makeKeyAndVisible()
    }

    /// Google's sign-in redirect returns through the app's reversed-client-ID URL scheme.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            _ = GIDSignIn.sharedInstance.handle(context.url)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        AnalyticsService.shared.track(.sessionStarted)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        AnalyticsService.shared.flush()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Reconcile authorization revoked in Settings while the app was in the background.
        DailyStudyReminder.restoreIfNeeded()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

