//
//  Haptics.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-29.
//

import CoreHaptics
import SwiftUI
import UIKit

// MARK: - HapticPattern

enum HapticPattern {
    case press
    case tap
    case select
    case tab
    case toggleOn
    case toggleOff
    case increase
    case decrease
    case scrub
    case sheetOpen
    case sheetClose
    case confirm
    case success
    case celebrate
    case warning
    case error
    case skip
    case resume
    case photo
}

// MARK: - Haptics

@MainActor
enum Haptics {
    private static var engine: CHHapticEngine?
    private static var coreHapticsUnavailable = false

    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    // MARK: - Play

    static func play(_ pattern: HapticPattern) {
        switch pattern {
        case .press:
            soft.impactOccurred(intensity: 0.35)
        case .tap:
            light.impactOccurred(intensity: 0.7)
        case .select:
            selection.selectionChanged()
        case .tab:
            rigid.impactOccurred(intensity: 0.45)
        case .toggleOn:
            sequence([Beat(0, 0.55, 0.3), Beat(0.07, 0.9, 0.8)], fallback: .rigid)
        case .toggleOff:
            sequence([Beat(0, 0.8, 0.7), Beat(0.07, 0.4, 0.2)], fallback: .soft)
        case .increase:
            sequence([Beat(0, 0.3, 0.4), Beat(0.05, 0.5, 0.5), Beat(0.1, 0.75, 0.6)], fallback: .light)
        case .decrease:
            sequence([Beat(0, 0.75, 0.6), Beat(0.05, 0.5, 0.5), Beat(0.1, 0.3, 0.4)], fallback: .light)
        case .scrub:
            light.impactOccurred(intensity: 0.4)
        case .sheetOpen:
            sequence([Beat(0, 0.35, 0.2), Beat(0.09, 0.6, 0.3)], fallback: .soft)
        case .sheetClose:
            sequence([Beat(0, 0.5, 0.3), Beat(0.08, 0.25, 0.15)], fallback: .soft)
        case .confirm:
            sequence([Beat(0, 0.6, 0.5), Beat(0.1, 0.9, 0.7)], fallback: .medium)
        case .success:
            notification.notificationOccurred(.success)
        case .celebrate:
            sequence([Beat(0, 0.4, 0.4), Beat(0.08, 0.6, 0.5), Beat(0.16, 0.85, 0.7), Beat(0.3, 1.0, 0.9)], fallback: .heavy)
        case .warning:
            notification.notificationOccurred(.warning)
        case .error:
            notification.notificationOccurred(.error)
        case .skip:
            continuous(intensity: 0.5, sharpness: 0.15, duration: 0.35, thenTap: 0.8, fallback: .heavy)
        case .resume:
            continuous(intensity: 0.3, sharpness: 0.1, duration: 0.2, thenTap: 0.6, fallback: .medium)
        case .photo:
            sequence([Beat(0, 1.0, 0.9), Beat(0.06, 0.5, 0.3)], fallback: .rigid)
        }

        prepare()
    }

    static func prepare() {
        soft.prepare()
        light.prepare()
        selection.prepare()
        notification.prepare()
    }

    // MARK: - Beats

    private struct Beat {
        let time: TimeInterval
        let intensity: Float
        let sharpness: Float

        init(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) {
            self.time = time
            self.intensity = intensity
            self.sharpness = sharpness
        }
    }

    private enum Fallback {
        case soft
        case light
        case medium
        case rigid
        case heavy
    }

    private static func sequence(_ beats: [Beat], fallback: Fallback) {
        let events = beats.map { beat in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: beat.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: beat.sharpness)
                ],
                relativeTime: beat.time
            )
        }

        if !perform(events) {
            fire(fallback)
        }
    }

    private static func continuous(intensity: Float,
                                   sharpness: Float,
                                   duration: TimeInterval,
                                   thenTap: Float,
                                   fallback: Fallback) {
        let hum = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0,
            duration: duration
        )

        let tap = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: thenTap),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ],
            relativeTime: duration
        )

        if !perform([hum, tap]) {
            fire(fallback)
        }
    }

    // MARK: - Engine

    private static func perform(_ events: [CHHapticEvent]) -> Bool {
        guard !coreHapticsUnavailable else { return false }

        do {
            if engine == nil {
                let created = try CHHapticEngine()
                created.isAutoShutdownEnabled = true
                engine = created
            }

            guard let engine else { return false }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            if engine == nil {
                coreHapticsUnavailable = true
            }
            engine = nil
            return false
        }
    }

    private static func fire(_ fallback: Fallback) {
        switch fallback {
        case .soft: soft.impactOccurred()
        case .light: light.impactOccurred()
        case .medium: medium.impactOccurred()
        case .rigid: rigid.impactOccurred()
        case .heavy: heavy.impactOccurred()
        }
    }
}

// MARK: - View Helpers

extension View {
    func haptic<Value: Equatable>(_ pattern: HapticPattern, trigger: Value) -> some View {
        onChange(of: trigger) { _, _ in
            Haptics.play(pattern)
        }
    }

    func haptic<Value: Equatable>(_ pattern: HapticPattern,
                                  trigger: Value,
                                  when condition: @escaping (Value, Value) -> Bool) -> some View {
        onChange(of: trigger) { oldValue, newValue in
            if condition(oldValue, newValue) {
                Haptics.play(pattern)
            }
        }
    }

    func toggleHaptic(_ isOn: Bool) -> some View {
        onChange(of: isOn) { _, newValue in
            Haptics.play(newValue ? .toggleOn : .toggleOff)
        }
    }

    func presentationHaptic() -> some View {
        onAppear {
            Haptics.play(.sheetOpen)
        }
        .onDisappear {
            Haptics.play(.sheetClose)
        }
    }
}
