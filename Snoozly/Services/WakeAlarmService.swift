//
//  WakeAlarmService.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import ActivityKit
import AlarmKit
import Foundation
import SwiftUI
import os

private let alarmLog = Logger(subsystem: "com.dantedabramo.Snoozly", category: "Alarms")

enum WakeAlarmPermission {
    case notDetermined
    case authorized
    case denied
    case failed
}

enum WakeAlarmService {
    private static let signatureKey = "wakeAlarmSignature"

    static var permission: WakeAlarmPermission {
        mapState(AlarmManager.shared.authorizationState)
    }

    private static func mapState(_ state: AlarmManager.AuthorizationState) -> WakeAlarmPermission {
        switch state {
        case .authorized: .authorized
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    static func requestPermission() async -> WakeAlarmPermission {
        do {
            let state = try await AlarmManager.shared.requestAuthorization()
            return mapState(state)
        } catch {
            alarmLog.error("Alarm authorization failed: \(String(describing: error))")
            let current = permission
            return current == .notDetermined ? .failed : current
        }
    }

    static func reschedule(for plan: SleepPlan, force: Bool = false) async {
        if force, plan.hasAlarms, permission == .notDetermined {
            _ = await requestPermission()
        }

        let signature = plan.alarmSignature + "|\(permission)"
        if !force, UserDefaults.standard.string(forKey: signatureKey) == signature { return }

        if await AlarmKitScheduler.apply(plan: plan) {
            UserDefaults.standard.set(signature, forKey: signatureKey)
        }
    }
}

// MARK: - Scheduling

nonisolated struct SnoozlyAlarmMetadata: AlarmMetadata {}

nonisolated private struct AlarmSlot: Hashable {
    let minutes: Int
    let snoozeMinutes: Int
}

private enum AlarmKitScheduler {
    static func apply(plan: SleepPlan) async -> Bool {
        cancelAll()

        guard AlarmManager.shared.authorizationState != .denied else {
            alarmLog.notice("Alarms are denied for Snoozly, nothing scheduled")
            return false
        }

        let wanted = plan.sortedNights.filter { $0.isEnabled && $0.alarmEnabled }
        let groups = Dictionary(grouping: wanted) { night in
            AlarmSlot(minutes: night.wakeMinutes, snoozeMinutes: plan.effectiveSnoozeMinutes(for: night))
        }

        var allScheduled = true

        for (slot, nights) in groups {
            let weekdays = nights.map { localeWeekday($0.weekday.shifted(by: 1)) }
            let scheduled = await schedule(minutes: slot.minutes, weekdays: weekdays, snoozeMinutes: slot.snoozeMinutes)
            if !scheduled { allScheduled = false }
        }

        return allScheduled
    }

    private static func cancelAll() {
        let existing = (try? AlarmManager.shared.alarms) ?? []
        for alarm in existing {
            try? AlarmManager.shared.cancel(id: alarm.id)
        }
    }

    private static func schedule(minutes: Int, weekdays: [Locale.Weekday], snoozeMinutes: Int) async -> Bool {
        let stopButton = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")

        let presentation: AlarmPresentation

        if snoozeMinutes > 0 {
            let snoozeButton = AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz")
            let pauseButton = AlarmButton(text: "Pause", textColor: .white, systemImageName: "pause.fill")
            let resumeButton = AlarmButton(text: "Resume", textColor: .white, systemImageName: "play.fill")

            let alert = AlarmPresentation.Alert(
                title: "Good morning",
                stopButton: stopButton,
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .countdown
            )
            let counting = AlarmPresentation.Countdown(title: "Snoozing", pauseButton: pauseButton)
            let paused = AlarmPresentation.Paused(title: "Paused", resumeButton: resumeButton)

            presentation = AlarmPresentation(alert: alert, countdown: counting, paused: paused)
        } else {
            let alert = AlarmPresentation.Alert(title: "Good morning", stopButton: stopButton)
            presentation = AlarmPresentation(alert: alert)
        }

        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: SnoozlyAlarmMetadata(),
            tintColor: Color.dreamPurple
        )

        let time = Alarm.Schedule.Relative.Time(hour: minutes / 60, minute: minutes % 60)
        let schedule = Alarm.Schedule.relative(
            Alarm.Schedule.Relative(time: time, repeats: .weekly(weekdays))
        )

        let countdown: Alarm.CountdownDuration? = snoozeMinutes > 0
            ? Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval(snoozeMinutes * 60))
            : nil

        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: countdown,
            schedule: schedule,
            attributes: attributes,
            stopIntent: nil,
            secondaryIntent: nil,
            sound: .default
        )

        do {
            _ = try await AlarmManager.shared.schedule(id: UUID(), configuration: configuration)
            return true
        } catch {
            alarmLog.error("Could not schedule alarm for minute \(minutes): \(String(describing: error))")
            return false
        }
    }

    private static func localeWeekday(_ day: Weekday) -> Locale.Weekday {
        switch day {
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        case .sunday: .sunday
        }
    }
}
