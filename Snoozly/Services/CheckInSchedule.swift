//
//  CheckInSchedule.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-29.
//

import Foundation

// MARK: - CheckInSchedule

enum CheckInSchedule {
    static func dayKey(for date: Date = .now) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func isDue(plan: SleepPlan?,
                      hasCheckInToday: Bool,
                      lastPromptDay: String,
                      now: Date = .now) -> Bool {
        guard !hasCheckInToday, lastPromptDay != dayKey(for: now), let plan else { return false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let lastNight = plan.sortedNights.first(where: { $0.weekday == Weekday(date: yesterday) }),
              lastNight.isEnabled else { return false }

        guard now >= lastNight.wakeDate(evening: yesterday) else { return false }

        if let tonight = plan.sortedNights.first(where: { $0.weekday == Weekday(date: today) }), tonight.isEnabled {
            return now < tonight.windDownDate(evening: today, windDownMinutes: plan.windDownMinutes)
        }

        return true
    }
}
