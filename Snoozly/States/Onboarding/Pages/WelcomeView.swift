//
//  WelcomeView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI

struct WelcomeView: View {
    var isActive: Bool

    @Environment(\.onboardingWide) private var pageIsWide

    var body: some View {
        OnboardingPageContainer(centersContent: true) {
            if pageIsWide {
                HStack(spacing: 32) {
                    mascot
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 20) {
                        headline(centered: false)
                        features
                        note
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 20) {
                    headline(centered: true)
                    mascot
                    features
                    note
                }
            }
        }
    }

    private func headline(centered: Bool) -> some View {
        OnboardingHeadline(
            eyebrow: "Your little bedtime buddy",
            title: "A softer way to end your day.",
            subtitle: "Build a bedtime routine that feels good, one night at a time.",
            centered: centered,
            prominent: true
        )
        .reveal(isActive, delay: 0.05)
    }

    private var mascot: some View {
        MascotGlow(isActive: isActive)
            .reveal(isActive, delay: 0.18, offset: 30)
    }

    private var features: some View {
        VStack(spacing: 16) {
            FeatureRow(
                symbol: "moon.stars.fill",
                tint: Color.lavendar,
                title: "Find your rhythm",
                subtitle: "Build a routine around your real week."
            )
            .reveal(isActive, delay: 0.35)

            FeatureRow(
                symbol: "bell.badge.fill",
                tint: Color.starlightGold,
                title: "Wind down gently",
                subtitle: "Get a soft nudge when it's time to slow down."
            )
            .reveal(isActive, delay: 0.45)
        }
        .frame(maxWidth: 440)
    }

    private var note: some View {
        Text("Takes less than 90 seconds")
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Color.lavendar.opacity(0.6))
            .reveal(isActive, delay: 0.55)
    }
}

// MARK: - Mascot

private struct MascotGlow: View {
    var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || !isActive)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let pulse = sin(t * 1.2)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.dreamPurple.opacity(0.5), Color.dreamPurple.opacity(0)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .scaleEffect(1 + pulse * 0.05)

                floatingZs(t: t)

                SleepyCreatureView()
                    .frame(width: 190, height: 190)
                    .offset(y: sin(t * 1.1) * 4)
            }
            .frame(width: 220, height: 190)
        }
        .accessibilityHidden(true)
    }

    private func floatingZs(t: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let p = (t * 0.3 + Double(i) / 3).truncatingRemainder(dividingBy: 1)

                Text("z")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(i == 1 ? Color.starlightGold : Color.lavendar)
                    .scaleEffect(0.6 + p * 0.9)
                    .rotationEffect(.degrees(-12 + p * 24))
                    .offset(x: 70 + p * 30, y: -30 - p * 80)
                    .opacity(sin(p * Double.pi) * 0.9)
            }
        }
    }
}

// MARK: - Feature row

private struct FeatureRow: View {
    let symbol: String
    let tint: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(spacing: 16) {
            RowIcon(systemName: symbol, size: 46, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack {
        NightBackground()
        WelcomeView(isActive: true)
            .padding()
    }
}
