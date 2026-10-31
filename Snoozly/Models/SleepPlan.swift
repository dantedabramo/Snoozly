//
//  SleepPlan.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import Foundation
import SwiftData

// MARK: - SleepPlan Model

@Model
final class SleepPlan {
    var windDownMinutes: Int
    var createdAt: Date
    var notificationsEnabled: Bool = false
    var blocksAppsDuringWindDown: Bool = false
    var blockedAppsData: Data?
    var snoozeMinutes: Int = 5
    var phoneHabitRaw: String?

    @Relationship(deleteRule: .cascade, inverse: \NightPlan.plan)
    var nights: [NightPlan]

    init(windDownMinutes: Int = 30,
         createdAt: Date = .now) {
        self.windDownMinutes = windDownMinutes
        self.createdAt = createdAt
        self.nights = []
    }
}

// MARK: - NightPlan Model

@Model
final class NightPlan {
    var weekdayIndex: Int
    var isEnabled: Bool
    var bedtimeMinutes: Int
    var wakeMinutes: Int
    var alarmEnabled: Bool = false
    var quietAppsEnabled: Bool = true
    var remindersEnabled: Bool = true
    var snoozeEnabled: Bool = true
    var plan: SleepPlan?

    init(weekday: Weekday,
         isEnabled: Bool = true,
         bedtimeMinutes: Int,
         wakeMinutes: Int,
         alarmEnabled: Bool = false,
         quietAppsEnabled: Bool = true,
         remindersEnabled: Bool = true,
         snoozeEnabled: Bool = true) {
        self.weekdayIndex = weekday.rawValue
        self.isEnabled = isEnabled
        self.bedtimeMinutes = bedtimeMinutes
        self.wakeMinutes = wakeMinutes
        self.alarmEnabled = alarmEnabled
        self.quietAppsEnabled = quietAppsEnabled
        self.remindersEnabled = remindersEnabled
        self.snoozeEnabled = snoozeEnabled
    }
}

// MARK: - Conveniences

extension NightPlan {
    var weekday: Weekday { Weekday(rawValue: weekdayIndex) ?? .monday }

    var sleepMinutes: Int { (wakeMinutes - bedtimeMinutes + 24 * 60) % (24 * 60) }
}

extension SleepPlan {
    var sortedNights: [NightPlan] {
        nights.sorted { $0.weekdayIndex < $1.weekdayIndex }
    }

    func night(forMorning morning: Weekday) -> NightPlan? {
        nights.first { $0.weekday == morning.nightBefore }
    }

    var averageSleepMinutes: Int? {
        let active = sortedNights.filter { $0.isEnabled }
        guard !active.isEmpty else { return nil }
        return active.map(\.sleepMinutes).reduce(0, +) / active.count
    }

    var phoneHabit: PhoneHabit? {
        get { phoneHabitRaw.flatMap(PhoneHabit.init(rawValue:)) }
        set { phoneHabitRaw = newValue?.rawValue }
    }

    var alarmNightCount: Int {
        sortedNights.filter { $0.isEnabled && $0.alarmEnabled }.count
    }

    var hasAlarms: Bool { alarmNightCount > 0 }

    var alarmSignature: String {
        let nights = sortedNights.map { night in
            let isOn = night.isEnabled && night.alarmEnabled
            let snooze = night.snoozeEnabled ? "s" : "n"
            return "\(night.weekdayIndex):\(isOn ? "\(night.wakeMinutes)\(snooze)" : "-1")"
        }
        return (["snooze\(snoozeMinutes)"] + nights).joined(separator: "|")
    }

    func effectiveSnoozeMinutes(for night: NightPlan) -> Int {
        night.snoozeEnabled ? snoozeMinutes : 0
    }

    static let snoozeChoices = [0, 1, 2, 3, 4, 5, 10, 15]

    func normalizeSnooze() {
        guard !Self.snoozeChoices.contains(snoozeMinutes) else { return }
        let lengths = Self.snoozeChoices.filter { $0 > 0 }
        snoozeMinutes = lengths.min { abs($0 - snoozeMinutes) < abs($1 - snoozeMinutes) } ?? 5
    }

    var quietSignature: String {
        let nights = sortedNights.map { night in
            let flags = (night.alarmEnabled ? "a" : "") + (night.snoozeEnabled ? "s" : "")
            return "\(night.weekdayIndex):\(night.isEnabled && night.quietAppsEnabled ? "\(night.bedtimeMinutes)-\(night.wakeMinutes)\(flags)" : "off")"
        }
        return (["\(blocksAppsDuringWindDown)", "\(windDownMinutes)", "snooze\(snoozeMinutes)"] + nights).joined(separator: "|")
    }

    var notificationSignature: [Int] {
        [windDownMinutes, notificationsEnabled ? 1 : 0]
            + sortedNights.flatMap { [$0.weekdayIndex, ($0.isEnabled && $0.remindersEnabled) ? 1 : 0, $0.bedtimeMinutes] }
    }

    @MainActor
    @discardableResult
    static func makeDefault(in context: ModelContext) -> SleepPlan {
        let plan = SleepPlan()
        context.insert(plan)
        for day in Weekday.allCases {
            let night = NightPlan(weekday: day,
                                  bedtimeMinutes: day.isLateNight ? 23 * 60 : 22 * 60,
                                  wakeMinutes: day.isLateNight ? 8 * 60 + 30 : 7 * 60)
            context.insert(night)
            night.plan = plan
        }
        return plan
    }
}

// MARK: - Time helpers

extension Date {
    static func today(atMinutes minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60,
                              minute: minutes % 60,
                              second: 0,
                              of: .now) ?? .now
    }

    var minutesAfterMidnight: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

extension Int {
    var durationText: String {
        Duration.seconds(self * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    var clockText: String {
        Date.today(atMinutes: self).formatted(date: .omitted, time: .shortened)
    }

    var compactClockText: String {
        Date.today(atMinutes: self).formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
    }
}

struct PreviewSleepPlan {
    let container: ModelContainer
    let plan: SleepPlan

    @MainActor
    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: SleepPlan.self, NightPlan.self, SleepCheckIn.self, configurations: config)
        plan = SleepPlan.makeDefault(in: container.mainContext)
    }
}
