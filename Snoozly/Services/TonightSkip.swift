//
//  TonightSkip.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-25.
//

import Foundation

// MARK: - TonightSkip

enum TonightSkip {
    static func nightKey(plan: SleepPlan?) -> String {
        NightClock.current(plan: plan).key
    }

    static func skippedNight(plan: SleepPlan?) -> NightRef? {
        let current = NightClock.current(plan: plan)
        return UserDefaults.standard.string(forKey: AppStorageKey.skipDateString) == current.key ? current : nil
    }

    static func isSkippedEvening(_ evening: Date) -> Bool {
        let key = NightRef(evening: Calendar.current.startOfDay(for: evening)).key
        return UserDefaults.standard.string(forKey: AppStorageKey.skipDateString) == key
    }

    static func isSkipped(plan: SleepPlan?) -> Bool {
        UserDefaults.standard.string(forKey: AppStorageKey.skipDateString) == nightKey(plan: plan)
    }

    static func set(_ skipped: Bool, plan: SleepPlan?) {
        UserDefaults.standard.set(skipped ? nightKey(plan: plan) : "", forKey: AppStorageKey.skipDateString)
    }

    static func toggle(plan: SleepPlan?) {
        set(!isSkipped(plan: plan), plan: plan)
    }
}
