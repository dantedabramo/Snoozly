//
//  WakeUpView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI
import SwiftData

struct MorningPlanItem: Identifiable {
    var id: Weekday { morning }
    let morning: Weekday
    let night: NightPlan
}

struct WakeUpView: View {
    var plan: SleepPlan
    var isActive: Bool

    @State private var selection: Weekday = .monday
    @State private var alarmIssue: WakeAlarmPermission?
    @Environment(\.onboardingWide) private var pageIsWide

    @State private var appearTick = 0

    private let quickPicks = [6 * 60, 6 * 60 + 30, 7 * 60, 7 * 60 + 30, 8 * 60, 8 * 60 + 30]

    private var morningItems: [MorningPlanItem] {
        Weekday.allCases.compactMap { morning in
            guard let night = plan.night(forMorning: morning) else { return nil }
            return MorningPlanItem(morning: morning, night: night)
        }
    }

    private var anyNightEnabled: Bool { plan.sortedNights.contains { $0.isEnabled } }

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
                        subtitle: "Set your wake-up time for each morning."
                    )
                    .reveal(isActive, delay: 0.05)

                    DayChipRow(
                        items: morningItems,
                        selection: $selection,
                        day: \.morning,
                        isEnabled: { $0.night.isEnabled },
                        subtitle: { $0.night.wakeMinutes.compactClockText }
                    )
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
                    if let item = morningItems.first(where: { $0.morning == selection }) {
                        MorningEditor(
                            night: item.night,
                            morning: item.morning,
                            quickPicks: quickPicks,
                            alarm: alarmBinding(for: item.night)
                        ) {
                            applyToEveryMorning(from: item.morning, wakeMinutes: item.night.wakeMinutes)
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

    private func applyToEveryMorning(from sourceMorning: Weekday, wakeMinutes: Int) {
        withAnimation(.snappy) {
            for item in morningItems {
                guard item.night.isEnabled else { continue }
                if item.morning.isWeekendMorning == sourceMorning.isWeekendMorning {
                    item.night.wakeMinutes = wakeMinutes
                }
            }
        }
    }
}

private struct MorningEditor: View {
    @Bindable var night: NightPlan
    let morning: Weekday
    let quickPicks: [Int]
    let alarm: Binding<Bool>
    let onApplyToAll: () -> Void

    private var sleepText: String {
        let minutes = (night.wakeMinutes - night.bedtimeMinutes + 24 * 60) % (24 * 60)
        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    var body: some View {
        NightTimeCard(
            title: "\(morning.fullName) Morning",
            subtitle: "After \(night.weekday.fullName) night",
            caption: "Wake-up",
            symbol: "sunrise.fill",
            accent: Color.starlightGold,
            detail: "\(sleepText) of sleep",
            isEnabled: $night.isEnabled,
            minutes: $night.wakeMinutes,
            quickPicks: quickPicks,
            disabledMessage: "No sleep scheduled for \(night.weekday.fullName) night.",
            applyToAllTitle: morning.isWeekendMorning
                ? "Use this time on weekend mornings (Sat–Sun)"
                : "Use this time on weekday mornings (Mon–Fri)",
            onApplyToAll: onApplyToAll,
            alarm: alarm,
            showsEnabledToggle: false
        )
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    ZStack {
        NightBackground()
        WakeUpView(plan: preview.plan, isActive: true)
    }
}
