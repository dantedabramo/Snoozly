//
//  ReviewView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import SwiftUI
import SwiftData

struct ReviewView: View {
    var plan: SleepPlan
    var isActive: Bool
    var goTo: (OnboardingStep) -> Void
    
    @Environment(\.onboardingWide) private var pageIsWide

    private var windDownDetail: LocalizedStringKey {
        if plan.notificationsEnabled {
            return "\(plan.windDownMinutes) min before bed · reminders on"
        }
        return "\(plan.windDownMinutes) min before bed"
    }

    private var quietAppsDetail: LocalizedStringKey {
        plan.blocksAppsDuringWindDown ? "On · until you wake" : "Off"
    }

    private var alarmDetail: LocalizedStringKey {
        let count = plan.alarmNightCount
        let mornings = count == 1 ? "1 morning" : "\(count) mornings"
        if plan.snoozeMinutes > 0 {
            return "\(mornings) · snooze \(plan.snoozeMinutes) min"
        }
        return "\(mornings) · no snooze"
    }

    var body: some View {
        OnboardingPageContainer(centersContent: true) {
            let isWide = pageIsWide
            let layout = isWide
                ? AnyLayout(HStackLayout(alignment: .center, spacing: 28))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))

            layout {
                VStack(alignment: .leading, spacing: 12) {
                    OnboardingHeadline(
                        title: "Your sleep plan.",
                        subtitle: "Everything look right? You can change it anytime."
                    )
                    .reveal(isActive, delay: 0.05)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 12) {
                    weekCard
                        .reveal(isActive, delay: 0.15, offset: 26)

                    settingsCard
                        .reveal(isActive, delay: 0.3, offset: 26)
                }
                .frame(maxWidth: 560, alignment: .leading)
            }
        }
    }

    // MARK: - Week

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    if let average = plan.averageSleepMinutes {
                        Text("About \(average.durationText) of sleep a night")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(Color.starlightGold.opacity(0.9))
                    }
                }

                Spacer(minLength: 8)

                Menu {
                    Button("Edit bedtimes") { goTo(.bedtime) }
                    Button("Edit wake-up times") { goTo(.wakeUp) }
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.lavendar)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }

            VStack(spacing: 0) {
                ForEach(plan.sortedNights) { night in
                    nightRow(night)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard(cornerRadius: 28)
    }

    private func nightRow(_ night: NightPlan) -> some View {
        HStack(spacing: 10) {
            Text(night.weekday.shortName)
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .foregroundStyle(night.isEnabled ? Color.lavendar : Color.white.opacity(0.35))
                .frame(width: 40, alignment: .leading)

            if night.isEnabled {
                Text("\(night.bedtimeMinutes.clockText) → \(night.wakeMinutes.clockText)")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 6)

                Text(night.sleepMinutes.durationText)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.lavendar.opacity(0.8))

                if plan.hasAlarms {
                    Image(systemName: night.alarmEnabled ? "alarm.fill" : "alarm")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(night.alarmEnabled ? Color.starlightGold : Color.white.opacity(0.2))
                        .frame(width: 18)
                }
            } else {
                Text("Off")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.35))

                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: 28)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Settings

    private var settingsCard: some View {
        VStack(spacing: 0) {
            summaryRow(symbol: "moon.stars.fill",
                       tint: Color.lavendar,
                       title: "Wind-down",
                       detail: windDownDetail,
                       step: .windDown)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.vertical, 2)

            summaryRow(symbol: "hourglass",
                       tint: Color.starlightGold,
                       title: "Quiet your apps",
                       detail: quietAppsDetail,
                       step: .windDown)

            if plan.hasAlarms {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.vertical, 2)

                summaryRow(symbol: "alarm.fill",
                           tint: Color.dreamCoral,
                           title: "Alarm",
                           detail: alarmDetail,
                           step: .alarm)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard(cornerRadius: 28)
    }

    private func summaryRow(symbol: String,
                            tint: Color,
                            title: LocalizedStringKey,
                            detail: LocalizedStringKey,
                            step: OnboardingStep) -> some View {
        Button {
            goTo(step)
        } label: {
            HStack(spacing: 12) {
                RowIcon(systemName: symbol, size: 36, tint: tint)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(detail)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.lavendar.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.lavendar.opacity(0.5))
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    ZStack {
        NightBackground()
        ReviewView(plan: preview.plan, isActive: true, goTo: { _ in })
            .padding()
    }
    .modelContainer(preview.container)
}

