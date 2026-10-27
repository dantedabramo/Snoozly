//
//  OnboardingStep.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case purpose
    case howItHelps
    case bedtime
    case wakeUp
    case alarm
    case windDown
    case review

    var id: Int { rawValue }

    var showsBackButton: Bool { self != .welcome }

    var forwardTitle: LocalizedStringKey {
        switch self {
        case .welcome: "Let's get cozy"
        case .howItHelps: "Let's set it up"
        case .purpose, .bedtime, .wakeUp, .alarm, .windDown: "Next"
        case .review: "Make this my routine"
        }
    }

    var forwardIcon: String? {
        switch self {
        case .welcome: nil
        case .review: "sparkles"
        default: "arrow.right"
        }
    }

    static func visible(for plan: SleepPlan) -> [OnboardingStep] {
        allCases.filter { $0 != .alarm || plan.hasAlarms }
    }
}
