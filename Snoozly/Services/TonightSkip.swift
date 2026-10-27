//
//  TonightSkip.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-25.
//

import Foundation

// MARK: - TonightSkip

enum TonightSkip {
    static var nightKey: String {
        let shifted = Calendar.current.date(byAdding: .hour, value: -6, to: .now) ?? .now
        return shifted.formatted(.iso8601.year().month().day())
    }

    static var isSkipped: Bool {
        UserDefaults.standard.string(forKey: AppStorageKey.skipDateString) == nightKey
    }

    static func set(_ skipped: Bool) {
        UserDefaults.standard.set(skipped ? nightKey : "", forKey: AppStorageKey.skipDateString)
    }

    static func toggle() {
        set(!isSkipped)
    }
}
