//
//  ScreenTimeService.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import os

enum ScreenTimeService {
    static let activityPrefix = "snoozly.quiet."
    private static let signatureKey = "quietHoursSignature"
    private static let log = Logger(subsystem: "com.dantedabramo.Snoozly", category: "ScreenTime")

    // MARK: - Authorization

    static let pickerSettleDelay: Duration = .milliseconds(250)

    static var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    static var status: PermissionStatus {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: .granted
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    static func requestAuthorization() async -> Bool {
        await requestAccess() == .granted
    }

    static func requestAccess() async -> PermissionStatus {
        if isAuthorized { return .granted }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return status
        } catch {
            log.error("Screen Time authorization failed: \(error.localizedDescription)")

            if isAuthorized { return .granted }

            if let familyError = error as? FamilyControlsError, familyError == .authorizationCanceled {
                return status
            }
            return status == .denied ? .denied : .failed
        }
    }

    // MARK: - Selection

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        AppGroup.defaults.set(data, forKey: AppGroup.selectionKey)
    }

    static func prepareForPicker() async -> PermissionStatus {
        let wasAuthorized = isAuthorized
        let result = await requestAccess()
        guard result == .granted else { return result }

        if !wasAuthorized {
            try? await Task.sleep(for: pickerSettleDelay)
        }
        return .granted
    }

    static func savedSelection(for plan: SleepPlan) -> FamilyActivitySelection {
        selection(for: plan) ?? FamilyActivitySelection()
    }

    static func selectionCount(for plan: SleepPlan) -> Int {
        guard let selection = selection(for: plan) else { return 0 }
        return selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    static func isReady(for plan: SleepPlan) -> Bool {
        plan.blocksAppsDuringWindDown && isAuthorized && selectionCount(for: plan) > 0
    }

    static func didChooseApps(_ selection: FamilyActivitySelection, for plan: SleepPlan) {
        plan.blockedAppsData = try? JSONEncoder().encode(selection)
        saveSelection(selection)
        plan.blocksAppsDuringWindDown = !isEmpty(selection)
        reschedule(for: plan, force: true)
    }

    private static func selection(for plan: SleepPlan) -> FamilyActivitySelection? {
        if let data = plan.blockedAppsData,
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            return selection
        }

        guard let data = AppGroup.defaults.data(forKey: AppGroup.selectionKey) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    private static func isEmpty(_ selection: FamilyActivitySelection) -> Bool {
        selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    // MARK: - Schedule

    static func reschedule(for plan: SleepPlan, force: Bool = false) {
        let defaults = UserDefaults.standard
        let savedSignature = defaults.string(forKey: signatureKey)

        guard plan.blocksAppsDuringWindDown else {
            let wasActive = savedSignature.map { $0 != "off" } ?? false
            if force || wasActive { stopAll() }
            return
        }

        guard isAuthorized else {
            log.notice("Screen Time not authorized yet, leaving schedule untouched")
            return
        }

        guard let selection = selection(for: plan), !isEmpty(selection) else {
            if force { stopAll() }
            return
        }

        saveSelection(selection)

        let signature = plan.quietSignature
        let changed = force || savedSignature != signature

        if changed {
            restartMonitoring(for: plan, signature: signature)
        }

        if isInQuietWindow(plan: plan) {
            applyShield(selection)
        } else if changed {
            ManagedSettingsStore().clearAllSettings()
        }
    }

    private static func stopAll() {
        DeviceActivityCenter().stopMonitoring()
        ManagedSettingsStore().clearAllSettings()
        UserDefaults.standard.set("off", forKey: signatureKey)
    }

    private static func restartMonitoring(for plan: SleepPlan, signature: String) {
        let center = DeviceActivityCenter()
        center.stopMonitoring()

        var failed = false

        for night in plan.sortedNights where night.isEnabled {
            let window = quietWindow(for: night, windDownMinutes: plan.windDownMinutes)
            let schedule = DeviceActivitySchedule(
                intervalStart: window.start,
                intervalEnd: window.end,
                repeats: true
            )
            let name = DeviceActivityName(activityPrefix + String(night.weekdayIndex))

            do {
                try center.startMonitoring(name, during: schedule)
            } catch {
                failed = true
                log.error("Could not monitor \(name.rawValue): \(error.localizedDescription)")
            }
        }

        if !failed {
            UserDefaults.standard.set(signature, forKey: signatureKey)
        }
    }

    // MARK: - Shield

    private static func applyShield(_ selection: FamilyActivitySelection) {
        let store = ManagedSettingsStore()

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

    // MARK: - Windows

    private static func isInQuietWindow(plan: SleepPlan, now: Date = .now) -> Bool {
        let calendar = Calendar.current

        for night in plan.sortedNights where night.isEnabled {
            let window = quietWindow(for: night, windDownMinutes: plan.windDownMinutes)

            guard let start = calendar.nextDate(after: now,
                                                matching: window.start,
                                                matchingPolicy: .nextTime,
                                                direction: .backward),
                  let end = calendar.nextDate(after: start,
                                              matching: window.end,
                                              matchingPolicy: .nextTime) else {
                continue
            }

            if now < end { return true }
        }

        return false
    }

    private static func quietWindow(for night: NightPlan,
                                    windDownMinutes: Int) -> (start: DateComponents, end: DateComponents) {
        let bedtimeDay = night.weekday.shifted(by: night.bedtimeMinutes < 6 * 60 ? 1 : 0)

        let startMinutes = night.bedtimeMinutes - windDownMinutes
        let startShift = startMinutes < 0 ? -1 : 0
        let startWrapped = ((startMinutes % (24 * 60)) + 24 * 60) % (24 * 60)

        var start = DateComponents()
        start.weekday = bedtimeDay.shifted(by: startShift).calendarWeekday
        start.hour = startWrapped / 60
        start.minute = startWrapped % 60

        var end = DateComponents()
        end.weekday = night.weekday.shifted(by: 1).calendarWeekday
        end.hour = night.wakeMinutes / 60
        end.minute = night.wakeMinutes % 60

        return (start, end)
    }
}
