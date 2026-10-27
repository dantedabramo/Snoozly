//
//  WakeUpView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI
import SwiftData

struct WakeUpView: View {
    var plan: SleepPlan
    var isActive: Bool

    @State private var selection: Weekday = .monday
    @State private var alarmIssue: WakeAlarmPermission?
    @Environment(\.onboardingWide) private var pageIsWide

    @State private var appearTick = 0

    private let quickPicks = [6 * 60, 6 * 60 + 30, 7 * 60, 7 * 60 + 30, 8 * 60, 8 * 60 + 30]

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
                        title: "What time do you wake up?",
                        subtitle: "Set your wake-up time for each day."
                    )
                    .reveal(isActive, delay: 0.05)

                    DayChipRow(nights: nights, selection: $selection) { night in
                        night.wakeMinutes.compactClockText
                    }
                    .reveal(isActive, delay: 0.15)

                    if !isWide {
                        if alarmIssue == .denied {
                            PermissionHint(text: "Alarms are off for Snoozly. You can allow them in Settings.")
                                .transition(.opacity)
                        }

                        if alarmIssue == .failed {
                            PermissionHint(text: "Couldn't confirm alarm permission yet. Your alarm is saved. You can allow alarms in Settings.")
                                .transition(.opacity)
                        }

                        if !anyNightEnabled {
                            OnboardingHint(text: "Turn on at least one morning to continue.")
                                .transition(.opacity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 16) {
                    if let night = nights.first(where: { $0.weekday == selection }) {
                        MorningEditor(night: night, quickPicks: quickPicks, alarm: alarmBinding(for: night)) {
                            applyToEveryMorning(from: night)
                        }
                        .reveal(isActive, delay: 0.25, offset: 26)
                        .frame(maxWidth: 560, alignment: .topLeading)
                    }

                    if isWide {
                        if alarmIssue == .denied {
                            PermissionHint(text: "Alarms are off for Snoozly. You can allow them in Settings.")
                                .transition(.opacity)
                        }

                        if alarmIssue == .failed {
                            PermissionHint(text: "Couldn't confirm alarm permission yet. Your alarm is saved. You can allow alarms in Settings.")
                                .transition(.opacity)
                        }

                        if !anyNightEnabled {
                            OnboardingHint(text: "Turn on at least one morning to continue.")
                                .transition(.opacity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .id(appearTick)
        .animation(.easeOut(duration: 0.25), value: anyNightEnabled)
        .animation(.easeOut(duration: 0.25), value: alarmIssue == nil)
        .onAppear { appearTick += 1 }
    }

    private func alarmBinding(for night: NightPlan) -> Binding<Bool> {
        Binding(
            get: { night.alarmEnabled },
            set: { setAlarm($0, for: night) }
        )
    }

    private func setAlarm(_ isOn: Bool, for night: NightPlan) {
        alarmIssue = nil

        guard isOn else {
            night.alarmEnabled = false
            return
        }

        night.alarmEnabled = true

        Task {
            let state = await WakeAlarmService.requestPermission()

            switch state {
            case .authorized:
                break
            case .denied:
                night.alarmEnabled = false
                alarmIssue = state
            case .notDetermined, .failed:
                alarmIssue = .failed
            }
        }
    }

    private func applyToEveryMorning(from source: NightPlan) {
        withAnimation(.snappy) {
            for night in nights
            where night.isEnabled && night.weekday.isLateNight == source.weekday.isLateNight {
                night.wakeMinutes = source.wakeMinutes
            }
        }
    }
}

private struct MorningEditor: View {
    @Bindable var night: NightPlan
    let quickPicks: [Int]
    let alarm: Binding<Bool>
    let onApplyToAll: () -> Void

    private var sleepText: String {
        let minutes = (night.wakeMinutes - night.bedtimeMinutes + 24 * 60) % (24 * 60)
        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    var body: some View {
        NightTimeCard(
            title: "\(night.weekday.fullName)",
            subtitle: "Wake-up time",
            caption: "Wake-up",
            symbol: "sunrise.fill",
            accent: Color.starlightGold,
            detail: "\(sleepText) of sleep",
            isEnabled: $night.isEnabled,
            minutes: $night.wakeMinutes,
            quickPicks: quickPicks,
            disabledMessage: "No wake-up plan this morning.",
            applyToAllTitle: night.weekday.isLateNight
                ? "Use this time on weekend mornings"
                : "Use this time on weekday mornings",
            onApplyToAll: onApplyToAll,
            alarm: alarm
        )
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    ZStack {
        NightBackground()
        WakeUpView(plan: preview.plan, isActive: true)
            .padding()
    }
    .modelContainer(preview.container)
}
