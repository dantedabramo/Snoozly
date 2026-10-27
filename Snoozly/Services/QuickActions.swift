//
//  QuickActions.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-25.
//

import SwiftUI
import UIKit

// MARK: - QuickAction

enum QuickAction: String {
    case checkIn = "com.dantedabramo.Snoozly.checkIn"
    case skipTonight = "com.dantedabramo.Snoozly.skipTonight"
    case schedule = "com.dantedabramo.Snoozly.schedule"
}

// MARK: - QuickActionRouter

@Observable
@MainActor
final class QuickActionRouter {
    static let shared = QuickActionRouter()

    var pending: QuickAction?

    private init() {}

    func handle(_ item: UIApplicationShortcutItem) {
        guard let action = QuickAction(rawValue: item.type) else { return }
        pending = action
    }

    func consume() -> QuickAction? {
        let action = pending
        pending = nil
        return action
    }

    func refreshShortcutItems(isSkipped: Bool) {
        let skipTitle = isSkipped
            ? String(localized: "Resume Tonight")
            : String(localized: "Skip Tonight")
        let skipIcon = isSkipped ? "arrow.counterclockwise" : "moon.zzz.fill"

        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: QuickAction.skipTonight.rawValue,
                localizedTitle: skipTitle,
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: skipIcon),
                userInfo: nil
            )
        ]
    }
}

// MARK: - App Delegate

final class SnoozlyAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            QuickActionRouter.shared.handle(shortcutItem)
        }

        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SnoozlySceneDelegate.self
        return configuration
    }
}

// MARK: - Scene Delegate

final class SnoozlySceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        QuickActionRouter.shared.handle(shortcutItem)
        completionHandler(true)
    }
}
