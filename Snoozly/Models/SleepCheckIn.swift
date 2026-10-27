//
//  SleepCheckIn.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-23.
//

import Foundation
import SwiftData

// MARK: - SleepCheckIn Model

@Model
final class SleepCheckIn {
    var id: UUID = UUID()
    var date: Date = Date.now
    var feel: String = "Good"
    var sleepQuality: String = "Sound"
    var hoursSlept: Double = 7.5
    var score: Int = 80
    var notes: String = ""
    var factorsRaw: String = ""

    init(id: UUID = UUID(),
         date: Date = .now,
         feel: String = "Good",
         sleepQuality: String = "Sound",
         hoursSlept: Double = 7.5,
         score: Int = 80,
         notes: String = "",
         factors: [SleepFactor] = []) {
        self.id = id
        self.date = date
        self.feel = feel
        self.sleepQuality = sleepQuality
        self.hoursSlept = hoursSlept
        self.score = score
        self.notes = notes
        self.factorsRaw = factors.map(\.rawValue).joined(separator: ",")
    }
}

// MARK: - Conveniences

extension SleepCheckIn {
    var factors: [SleepFactor] {
        get {
            factorsRaw
                .split(separator: ",")
                .compactMap { SleepFactor(rawValue: String($0)) }
        }
        set {
            factorsRaw = newValue.map(\.rawValue).joined(separator: ",")
        }
    }

    var feelValue: SleepFeel? {
        SleepFeel(rawValue: feel)
    }

    var qualityValue: SleepQuality? {
        SleepQuality(rawValue: sleepQuality)
    }
}

// MARK: - SleepFeel

enum SleepFeel: String, CaseIterable, Identifiable {
    case energized = "Energized"
    case good = "Good"
    case okay = "Okay"
    case tired = "Tired"
    case exhausted = "Exhausted"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .energized: "bolt.fill"
        case .good: "face.smiling.inverse"
        case .okay: "minus.circle.fill"
        case .tired: "cloud.moon.fill"
        case .exhausted: "battery.25"
        }
    }

    var points: Int {
        switch self {
        case .energized: 40
        case .good: 32
        case .okay: 22
        case .tired: 12
        case .exhausted: 4
        }
    }
}

// MARK: - SleepQuality

enum SleepQuality: String, CaseIterable, Identifiable {
    case deep = "Deep & Restful"
    case sound = "Sound"
    case restless = "Restless"
    case interrupted = "Interrupted"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .deep: "moon.stars.fill"
        case .sound: "bed.double.fill"
        case .restless: "wind"
        case .interrupted: "exclamationmark.circle.fill"
        }
    }

    var points: Int {
        switch self {
        case .deep: 35
        case .sound: 28
        case .restless: 14
        case .interrupted: 6
        }
    }
}

// MARK: - SleepFactor

enum SleepFactor: String, CaseIterable, Identifiable {
    case caffeine = "Caffeine"
    case lateScreens = "Late screens"
    case exercise = "Exercise"
    case alcohol = "Alcohol"
    case stress = "Stress"
    case reading = "Read before bed"
    case lateMeal = "Late meal"
    case nap = "Nap"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .caffeine: "cup.and.saucer.fill"
        case .lateScreens: "iphone"
        case .exercise: "figure.run"
        case .alcohol: "wineglass.fill"
        case .stress: "brain.head.profile"
        case .reading: "book.fill"
        case .lateMeal: "fork.knife"
        case .nap: "moon.zzz.fill"
        }
    }
}

// MARK: - SleepScoring

enum SleepScoring {
    static func score(feel: SleepFeel, quality: SleepQuality, hours: Double, goalHours: Double) -> Int {
        let gap = abs(hours - goalHours)
        let durationPoints = 25.0 * max(0, 1 - gap / 4.0)
        let total = Double(feel.points + quality.points) + durationPoints
        return min(100, max(0, Int(total.rounded())))
    }

    static func label(for score: Int) -> String {
        switch score {
        case 90...: "Excellent night"
        case 80..<90: "Great night"
        case 65..<80: "Decent night"
        case 50..<65: "Fair night"
        default: "Rough night"
        }
    }
}
