//
//  PermissionCenter.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-27.
//

import SwiftUI
import UIKit

// MARK: - PermissionStatus

enum PermissionStatus: Equatable {
    case notDetermined
    case granted
    case denied
    case failed
}

// MARK: - PermissionKind

enum PermissionKind {
    case notifications
    case alarms
    case screenTime

    var recoversInSettings: Bool {
        self != .screenTime
    }

    func detail(for status: PermissionStatus) -> LocalizedStringKey {
        switch (self, status) {
        case (.notifications, .granted): "Wind-down and bedtime reminders can reach you."
        case (.notifications, .denied): "Off for Snoozly in iOS Settings, so reminders won't arrive."
        case (.notifications, _): "Needed for wind-down and bedtime reminders."

        case (.alarms, .granted): "Your wake-up alarm can ring."
        case (.alarms, .denied): "Off for Snoozly in iOS Settings, so alarms won't ring."
        case (.alarms, .failed): "Couldn't confirm alarm access. Try again."
        case (.alarms, .notDetermined): "Needed so your wake-up alarm can ring."

        case (.screenTime, .granted): "Quiet Apps can block the apps you pick."
        case (.screenTime, .denied): "Access was declined, so no apps will be quieted."
        case (.screenTime, .failed): "Screen Time isn't available right now. Try again."
        case (.screenTime, .notDetermined): "Needed to quiet apps from wind-down until you wake."
        }
    }

    func actionTitle(for status: PermissionStatus) -> LocalizedStringKey {
        switch status {
        case .granted: "Allowed"
        case .notDetermined: "Allow"
        case .denied: recoversInSettings ? "Settings" : "Retry"
        case .failed: "Retry"
        }
    }

    func actionSymbol(for status: PermissionStatus) -> String {
        switch status {
        case .granted: "checkmark"
        case .notDetermined: "arrow.up.forward.app"
        case .denied: recoversInSettings ? "gearshape.fill" : "arrow.clockwise"
        case .failed: "arrow.clockwise"
        }
    }
}

// MARK: - PermissionCenter

@Observable
@MainActor
final class PermissionCenter {
    static let shared = PermissionCenter()

    private(set) var notifications: PermissionStatus = .notDetermined
    private(set) var alarms: PermissionStatus
    private(set) var screenTime: PermissionStatus
    private(set) var isPreparingScreenTime = false

    private init() {
        alarms = Self.status(for: WakeAlarmService.permission)
        screenTime = ScreenTimeService.status

        Task {
            await refresh()
        }
    }

    // MARK: - Status

    func status(of kind: PermissionKind) -> PermissionStatus {
        switch kind {
        case .notifications: notifications
        case .alarms: alarms
        case .screenTime: screenTime
        }
    }

    func refresh() async {
        notifications = Self.status(for: await NotificationManager.shared.access())
        alarms = Self.merged(alarms, with: Self.status(for: WakeAlarmService.permission))
        screenTime = Self.merged(screenTime, with: ScreenTimeService.status)
    }

    func remindersActive(for plan: SleepPlan?) -> Bool {
        plan?.notificationsEnabled == true && notifications == .granted
    }

    func quietAppsReady(for plan: SleepPlan?) -> Bool {
        guard let plan else { return false }
        return screenTime == .granted
            && plan.blocksAppsDuringWindDown
            && ScreenTimeService.selectionCount(for: plan) > 0
    }

    // MARK: - Notifications

    func allowNotifications(for plan: SleepPlan?) async {
        let live = await NotificationManager.shared.access()

        if live == .denied {
            notifications = .denied
            plan?.notificationsEnabled = true
            openNotificationSettings()
            return
        }

        guard let plan else {
            let granted = await NotificationManager.shared.requestAuthorization()
            notifications = granted ? .granted : .denied
            return
        }

        notifications = Self.status(for: await NotificationManager.shared.turnOnReminders(for: plan))
    }

    // MARK: - Alarms

    func allowAlarms(for plan: SleepPlan?) async {
        switch WakeAlarmService.permission {
        case .denied:
            alarms = .denied
            openSettings()
        case .authorized:
            alarms = .granted
        case .notDetermined, .failed:
            alarms = Self.status(for: await WakeAlarmService.requestPermission())
            if alarms == .granted, let plan {
                await WakeAlarmService.reschedule(for: plan, force: true)
            }
        }
    }

    // MARK: - Screen Time

    @discardableResult
    func allowScreenTime() async -> Bool {
        guard !isPreparingScreenTime else { return false }

        isPreparingScreenTime = true
        defer { isPreparingScreenTime = false }

        screenTime = await ScreenTimeService.prepareForPicker()
        return screenTime == .granted
    }

    // MARK: - Settings

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else {
            openSettings()
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: - Mapping

    private static func merged(_ old: PermissionStatus, with new: PermissionStatus) -> PermissionStatus {
        old == .failed && new == .notDetermined ? .failed : new
    }

    private static func status(for access: NotificationManager.Access) -> PermissionStatus {
        switch access {
        case .allowed: .granted
        case .denied: .denied
        case .notDetermined: .notDetermined
        }
    }

    private static func status(for permission: WakeAlarmPermission) -> PermissionStatus {
        switch permission {
        case .authorized: .granted
        case .denied: .denied
        case .notDetermined: .notDetermined
        case .failed: .failed
        }
    }
}
