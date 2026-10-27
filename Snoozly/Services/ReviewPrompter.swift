//
//  ReviewPrompter.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-25.
//

import Foundation

// MARK: - ReviewPrompter

enum ReviewPrompter {
    private static let minimumDaysSinceInstall = 7.0
    private static let minimumLaunches = 4
    private static let minimumCheckIns = 3
    private static let minimumScore = 70
    private static let cooldownDays = 120.0

    private static var defaults: UserDefaults {
        UserDefaults.standard
    }

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Tracking

    static func registerLaunch() {
        if defaults.double(forKey: AppStorageKey.firstLaunchDate) == 0 {
            defaults.set(Date.now.timeIntervalSince1970, forKey: AppStorageKey.firstLaunchDate)
        }
        defaults.set(defaults.integer(forKey: AppStorageKey.launchCount) + 1, forKey: AppStorageKey.launchCount)
    }

    static func markPrompted() {
        defaults.set(Date.now.timeIntervalSince1970, forKey: AppStorageKey.lastReviewPromptDate)
        defaults.set(currentVersion, forKey: AppStorageKey.lastReviewPromptVersion)
    }

    // MARK: - Policy

    static func shouldPrompt(checkInCount: Int, latestScore: Int) -> Bool {
        guard checkInCount >= minimumCheckIns, latestScore >= minimumScore else { return false }
        guard defaults.integer(forKey: AppStorageKey.launchCount) >= minimumLaunches else { return false }

        let now = Date.now.timeIntervalSince1970
        let firstLaunch = defaults.double(forKey: AppStorageKey.firstLaunchDate)
        guard firstLaunch > 0, now - firstLaunch >= minimumDaysSinceInstall * 86_400 else { return false }

        if defaults.string(forKey: AppStorageKey.lastReviewPromptVersion) == currentVersion {
            return false
        }

        let lastPrompt = defaults.double(forKey: AppStorageKey.lastReviewPromptDate)
        if lastPrompt > 0, now - lastPrompt < cooldownDays * 86_400 {
            return false
        }

        return true
    }
}
