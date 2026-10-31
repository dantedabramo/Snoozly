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
    private static let releaseKey = "quietHoldReleasedAt"
    static let snoozeHoldMinutes = 30
    private static let log = Logger(subsystem: "com.dantedabramo.Snoozly", category: "ScreenTime")

    // MARK: - Authorization

    static let pickerSettleDelay: Duration = .milliseconds(250)

    static var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    static var status: PermissionStatus {
        let current = AuthorizationCenter.shared.authorizationStatus

        switch current {
        case .approved: return .granted
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        default: return String(describing: current).hasPrefix("approved") ? .granted : .notDetermined
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

        let skipped = TonightSkip.skippedNight(plan: plan)
        let signature = plan.quietSignature + "|hold:\(WakeAlarmService.permission == .authorized)|skip:\(skipped?.key ?? "-")"
        let changed = force || savedSignature != signature

        if changed {
            restartMonitoring(for: plan, signature: signature, skipped: skipped)
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

    private static func restartMonitoring(for plan: SleepPlan, signature: String, skipped: NightRef?) {
        let center = DeviceActivityCenter()
        center.stopMonitoring()

        var failed = false

        for night in plan.sortedNights where night.isEnabled && night.quietAppsEnabled {
            if let skipped, skipped.weekday == night.weekday {
                if !scheduleOneTime(for: night, plan: plan, evening: skipped.shifted(byDays: 7).evening, center: center) {
                    failed = true
                }
                continue
            }

            let window = quietWindow(for: night, plan: plan)
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

    private static func scheduleOneTime(for night: NightPlan,
                                        plan: SleepPlan,
                                        evening: Date,
                                        center: DeviceActivityCenter) -> Bool {
        let calendar = Calendar.current
        let start = night.windDownDate(evening: evening, windDownMinutes: plan.windDownMinutes)
        let end = calendar.date(byAdding: .minute,
                                value: holdMinutes(for: night, plan: plan),
                                to: night.wakeDate(evening: evening)) ?? night.wakeDate(evening: evening)

        guard start > .now else { return true }

        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(parts, from: start),
            intervalEnd: calendar.dateComponents(parts, from: end),
            repeats: false
        )
        let name = DeviceActivityName(activityPrefix + "once." + String(night.weekdayIndex))

        do {
            try center.startMonitoring(name, during: schedule)
            return true
        } catch {
            log.error("Could not monitor \(name.rawValue): \(error.localizedDescription)")
            return false
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

    // MARK: - Snooze Hold

    private static func holdMinutes(for night: NightPlan, plan: SleepPlan) -> Int {
        guard WakeAlarmService.permission == .authorized,
              night.alarmEnabled,
              plan.effectiveSnoozeMinutes(for: night) > 0 else { return 0 }
        return snoozeHoldMinutes
    }

    static func releaseWakeHold() {
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: releaseKey)
        guard isAuthorized else { return }
        ManagedSettingsStore().clearAllSettings()
    }

    static func settleWakeHold(for plan: SleepPlan, now: Date = .now) {
        guard isAuthorized, plan.blocksAppsDuringWindDown else { return }
        guard isInHoldTail(plan: plan, now: now), !WakeAlarmService.isWakeInProgress else { return }
        releaseWakeHold()
    }

    private static func isHoldReleased(since baseEnd: Date) -> Bool {
        UserDefaults.standard.double(forKey: releaseKey) >= baseEnd.timeIntervalSince1970
    }

    // MARK: - Windows

    private struct Occurrence {
        let baseEnd: Date
        let end: Date

        var isSkipped: Bool {
            let day = Calendar.current.startOfDay(for: baseEnd)
            let evening = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
            return TonightSkip.isSkippedEvening(evening)
        }
    }

    private static func occurrence(for night: NightPlan, plan: SleepPlan, now: Date) -> Occurrence? {
        let calendar = Calendar.current
        let window = quietWindow(for: night, plan: plan)

        guard let start = calendar.nextDate(after: now,
                                            matching: window.start,
                                            matchingPolicy: .nextTime,
                                            direction: .backward),
              let baseEnd = calendar.nextDate(after: start,
                                              matching: window.baseEnd,
                                              matchingPolicy: .nextTime),
              let end = calendar.nextDate(after: start,
                                          matching: window.end,
                                          matchingPolicy: .nextTime) else {
            return nil
        }

        return Occurrence(baseEnd: baseEnd, end: end)
    }

    private static func isInQuietWindow(plan: SleepPlan, now: Date = .now) -> Bool {
        for night in plan.sortedNights where night.isEnabled && night.quietAppsEnabled {
            guard let found = occurrence(for: night, plan: plan, now: now), !found.isSkipped else { continue }

            if now < found.baseEnd { return true }
            if now < found.end && !isHoldReleased(since: found.baseEnd) { return true }
        }

        return false
    }

    private static func isInHoldTail(plan: SleepPlan, now: Date) -> Bool {
        for night in plan.sortedNights where night.isEnabled && night.quietAppsEnabled {
            guard let found = occurrence(for: night, plan: plan, now: now), !found.isSkipped else { continue }
            if now >= found.baseEnd && now < found.end { return true }
        }

        return false
    }

    private static func quietWindow(for night: NightPlan,
                                    plan: SleepPlan) -> (start: DateComponents, baseEnd: DateComponents, end: DateComponents) {
        let minutesPerDay = 24 * 60
        let bedtimeDay = night.weekday.shifted(by: night.bedtimeMinutes < 6 * 60 ? 1 : 0)

        let startMinutes = night.bedtimeMinutes - plan.windDownMinutes
        let startShift = startMinutes < 0 ? -1 : 0
        let startWrapped = ((startMinutes % minutesPerDay) + minutesPerDay) % minutesPerDay

        var start = DateComponents()
        start.weekday = bedtimeDay.shifted(by: startShift).calendarWeekday
        start.hour = startWrapped / 60
        start.minute = startWrapped % 60

        var baseEnd = DateComponents()
        baseEnd.weekday = night.weekday.shifted(by: 1).calendarWeekday
        baseEnd.hour = night.wakeMinutes / 60
        baseEnd.minute = night.wakeMinutes % 60

        let totalEnd = night.wakeMinutes + holdMinutes(for: night, plan: plan)

        var end = DateComponents()
        end.weekday = night.weekday.shifted(by: 1 + totalEnd / minutesPerDay).calendarWeekday
        end.hour = (totalEnd % minutesPerDay) / 60
        end.minute = totalEnd % 60

        return (start, baseEnd, end)
    }
}
