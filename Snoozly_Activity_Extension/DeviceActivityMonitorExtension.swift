//
//  DeviceActivityMonitorExtension.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()

    private let activityPrefix = "snoozly.quiet."
    private let groupIdentifier = "group.com.dantedabramo.Snoozly"
    private let selectionKey = "quietAppsSelection"

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue.hasPrefix(activityPrefix) else { return }
        applyShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue.hasPrefix(activityPrefix) else { return }
        store.clearAllSettings()
    }

    private func applyShield() {
        guard let data = UserDefaults(suiteName: groupIdentifier)?.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
            store.shield.webDomainCategories = .specific(selection.categoryTokens)
        }
    }
}
