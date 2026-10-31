//
//  NightClock.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-29.
//

import Foundation

// MARK: - NightRef

struct NightRef: Equatable {
    let evening: Date

    var weekday: Weekday {
        Weekday(date: evening)
    }

    var key: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: evening)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    func shifted(byDays days: Int) -> NightRef {
        let moved = Calendar.current.date(byAdding: .day, value: days, to: evening) ?? evening
        return NightRef(evening: moved)
    }
}

// MARK: - NightClock

enum NightClock {
    static func current(plan: SleepPlan?, now: Date = .now) -> NightRef {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        guard let plan,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return NightRef(evening: today)
        }

        let lastNight = plan.sortedNights.first { $0.weekday == Weekday(date: yesterday) }

        if let lastNight, lastNight.isEnabled, now < lastNight.wakeDate(evening: yesterday) {
            return NightRef(evening: yesterday)
        }

        return NightRef(evening: today)
    }

    static func night(on ref: NightRef, in plan: SleepPlan?) -> NightPlan? {
        plan?.sortedNights.first { $0.weekday == ref.weekday }
    }
}

// MARK: - NightPhase

enum NightPhase: Equatable {
    case beforeWindDown(minutes: Int)
    case windDown(minutesToBed: Int)
    case asleep(minutesToWake: Int)
    case finished
}

// MARK: - Night Dates

extension NightPlan {
    func bedtimeDate(evening: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: evening)
        let dayShift = bedtimeMinutes < 6 * 60 ? 1 : 0
        let day = calendar.date(byAdding: .day, value: dayShift, to: start) ?? start

        return calendar.date(bySettingHour: bedtimeMinutes / 60,
                             minute: bedtimeMinutes % 60,
                             second: 0,
                             of: day) ?? day
    }

    func wakeDate(evening: Date) -> Date {
        let bedtime = bedtimeDate(evening: evening)
        return Calendar.current.date(byAdding: .minute, value: sleepMinutes, to: bedtime) ?? bedtime
    }

    func windDownDate(evening: Date, windDownMinutes: Int) -> Date {
        let bedtime = bedtimeDate(evening: evening)
        return Calendar.current.date(byAdding: .minute, value: -windDownMinutes, to: bedtime) ?? bedtime
    }

    func phase(evening: Date, windDownMinutes: Int, now: Date = .now) -> NightPhase {
        let windDown = windDownDate(evening: evening, windDownMinutes: windDownMinutes)
        let bedtime = bedtimeDate(evening: evening)
        let wake = wakeDate(evening: evening)

        if now < windDown {
            return .beforeWindDown(minutes: Self.minutes(from: now, to: windDown))
        }
        if now < bedtime {
            return .windDown(minutesToBed: Self.minutes(from: now, to: bedtime))
        }
        if now < wake {
            return .asleep(minutesToWake: Self.minutes(from: now, to: wake))
        }
        return .finished
    }

    private static func minutes(from start: Date, to end: Date) -> Int {
        max(1, Int((end.timeIntervalSince(start) / 60).rounded(.up)))
    }
}
