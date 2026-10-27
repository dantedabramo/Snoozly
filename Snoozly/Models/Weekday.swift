//
//  Weekday.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import Foundation

enum Weekday: Int, CaseIterable, Identifiable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    private var symbolIndex: Int { (rawValue + 1) % 7 }

    var initial: String { Calendar.current.veryShortStandaloneWeekdaySymbols[symbolIndex] }
    var shortName: String { Calendar.current.shortStandaloneWeekdaySymbols[symbolIndex] }
    var fullName: String { Calendar.current.standaloneWeekdaySymbols[symbolIndex] }

    var calendarWeekday: Int { symbolIndex + 1 }

    var isLateNight: Bool { self == .friday || self == .saturday }

    func shifted(by days: Int) -> Weekday {
        Weekday(rawValue: ((rawValue + days) % 7 + 7) % 7) ?? self
    }
}

// MARK: - Dates

extension Weekday {
    init(date: Date) {
        let weekdayInt = Calendar.current.component(.weekday, from: date)
        self = Weekday(rawValue: (weekdayInt + 5) % 7) ?? .monday
    }

    static var today: Weekday {
        Weekday(date: .now)
    }
}
