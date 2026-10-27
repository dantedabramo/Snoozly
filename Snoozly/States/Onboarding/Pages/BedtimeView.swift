//
//  BedtimeView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI
import SwiftData

struct BedtimeView: View {
    var plan: SleepPlan
    var isActive: Bool

    @State private var selection: Weekday = .monday
    @State private var appearTick = 0
    @Environment(\.onboardingWide) private var pageIsWide

    private let quickPicks = [21 * 60, 21 * 60 + 30, 22 * 60, 22 * 60 + 30, 23 * 60, 23 * 60 + 30]

    private var nights: [NightPlan] { plan.sortedNights }
    private var anyNightEnabled: Bool { nights.contains { $0.isEnabled } }

    var body: some View {
        OnboardingPageContainer(centersContent: true) {
            let isWide = pageIsWide
            let layout = isWide
                ? AnyLayout(HStackLayout(alignment: .center, spacing: 28))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 16))

            layout {
                VStack(alignment: .leading, spacing: 16) {
                    OnboardingHeadline(
                        title: "When does your night begin?",
                        subtitle: "Pick a bedtime for each night. Weekends can be different."
                    )
                    .reveal(isActive, delay: 0.05)

                    DayChipRow(nights: nights, selection: $selection) { night in
                        night.bedtimeMinutes.compactClockText
                    }
                    .reveal(isActive, delay: 0.15)

                    if !isWide, !anyNightEnabled {
                        OnboardingHint(text: "Turn on at least one night to continue.")
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 16) {
                    if let night = nights.first(where: { $0.weekday == selection }) {
                        NightBedtimeEditor(night: night, quickPicks: quickPicks) {
                            applyToEveryNight(from: night)
                        }
                        .reveal(isActive, delay: 0.25, offset: 26)
                        .frame(maxWidth: 560, alignment: .topLeading)
                    }

                    if isWide, !anyNightEnabled {
                        OnboardingHint(text: "Turn on at least one night to continue.")
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .id(appearTick)
        .animation(.easeOut(duration: 0.25), value: anyNightEnabled)
        .onAppear { appearTick += 1 }
    }

    private func applyToEveryNight(from source: NightPlan) {
        withAnimation(.snappy) {
            for night in nights
            where night.isEnabled && night.weekday.isLateNight == source.weekday.isLateNight {
                night.bedtimeMinutes = source.bedtimeMinutes
            }
        }
    }
}

private struct NightBedtimeEditor: View {
    @Bindable var night: NightPlan
    let quickPicks: [Int]
    let onApplyToAll: () -> Void

    var body: some View {
        NightTimeCard(
            title: "\(night.weekday.fullName) night",
            caption: "Bedtime",
            symbol: "moon.stars.fill",
            accent: Color.lavendar,
            isEnabled: $night.isEnabled,
            minutes: $night.bedtimeMinutes,
            quickPicks: quickPicks,
            disabledMessage: "No bedtime this night. Snoozly will stay quiet.",
            applyToAllTitle: night.weekday.isLateNight
                ? "Use this time on weekend nights"
                : "Use this time on weekday nights",
            onApplyToAll: onApplyToAll
        )
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    ZStack {
        NightBackground()
        BedtimeView(plan: preview.plan, isActive: true)
            .padding()
    }
    .modelContainer(preview.container)
}
