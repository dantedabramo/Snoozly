//
//  OnboardingButtons.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI

// MARK: - Forward (prominent)

struct OnboardingForwardButton: View {
    var title: LocalizedStringKey
    var systemImage: String? = "arrow.right"
    var isEnabled: Bool = true
    var isBusy: Bool = false
    var action: () -> Void

    @State private var taps = 0

    var body: some View {
        Button {
            guard !isBusy else { return }
            taps += 1
            action()
        } label: {
            HStack(spacing: 10) {
                Text(title)

                if isBusy {
                    SwiftUI.ProgressView()
                        .tint(Color.midnightNavy)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .bold))
                }
            }
        }
        .buttonStyle(ProminentCapsuleButtonStyle())
        .disabled(!isEnabled)
        .haptic(.confirm, trigger: taps)
    }
}

private struct ProminentCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(Color.midnightNavy)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(colors: [Color.lavendar, Color.dreamPurple],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0)],
                                               startPoint: .top,
                                               endPoint: .bottom),
                                lineWidth: 1
                            )
                    }
            }
            .overlay {
                ShimmerSweep()
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.dreamPurple.opacity(isEnabled ? 0.45 : 0), radius: 20, y: 8)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.25), value: isEnabled)
    }
}

private struct ShimmerSweep: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        if reduceMotion || !isEnabled {
            Color.clear
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                GeometryReader { geo in
                    let cycle = 4.5
                    let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
                    let progress = min(phase / 0.35, 1)

                    LinearGradient(
                        colors: [Color.white.opacity(0), Color.white.opacity(0.35), Color.white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: -geo.size.width * 0.5 + progress * geo.size.width * 1.5)
                    .opacity(phase < 0.35 ? 1 : 0)
                }
            }
        }
    }
}

// MARK: - Back (quiet)

struct OnboardingBackButton: View {
    var action: () -> Void

    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.lavendar)
                .frame(width: 44, height: 44)
                .nightCard(cornerRadius: 22, blurs: false)
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .haptic(.tap, trigger: taps)
        .accessibilityLabel("Back")
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
            .haptic(.press, trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

#Preview {
    ZStack {
        Color.midnightNavy.ignoresSafeArea()
        VStack(spacing: 24) {
            OnboardingBackButton {}
            OnboardingForwardButton(title: "Let's get cozy") {}
            OnboardingForwardButton(title: "Next", isEnabled: false) {}
        }
        .padding(24)
    }
}
