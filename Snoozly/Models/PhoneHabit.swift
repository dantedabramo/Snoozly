//
//  PhoneHabit.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import SwiftUI

enum PhoneHabit: String, CaseIterable, Identifiable {
    case often
    case sometimes
    case rarely

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .often: "Most nights"
        case .sometimes: "Some nights"
        case .rarely: "Rarely"
        }
    }

    var symbol: String {
        switch self {
        case .often: "iphone.radiowaves.left.and.right"
        case .sometimes: "iphone"
        case .rarely: "iphone.slash"
        }
    }

    var response: LocalizedStringKey {
        switch self {
        case .often: "You're not alone. Snoozly can quiet your apps when it's time to wind down."
        case .sometimes: "A gentle nudge can make those nights easier."
        case .rarely: "Lovely. Snoozly will help you keep it that way."
        }
    }
}
