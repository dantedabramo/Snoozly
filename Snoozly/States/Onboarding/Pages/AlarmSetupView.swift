//
//  AlarmSetupView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import SwiftUI
import SwiftData

struct AlarmSetupView: View {
    @Bindable var plan: SleepPlan
    var isActive: Bool

    private let snoozeRows: [[Int]] = [[0, 1, 2, 3], [4, 5, 10, 15]]

    private var nights: [NightPlan] { plan.sortedNights }

    var body: some View {
        OnboardingPageContainer(centersContent: true) {
            VStack(alignment: .leading, spacing: 16) {
                OnboardingHeadline(
                    title: "Wake up gently.",
                    subtitle: "Your alarm keeps ringing until you stop it or snooze."
                )
                .reveal(isActive, delay: 0.05)

                morningsCard
                    .reveal(isActive, delay: 0.15, offset: 26)

                snoozeCard
                    .reveal(isActive, delay: 0.25, offset: 26)

                Label("Uses Apple's standard alarm sound.", systemImage: "speaker.wave.2.fill")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.6))
                    .reveal(isActive, delay: 0.35)
            }
        }
    }

    // MARK: - Mornings

    private var morningsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Wake-up alarms")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text("Rings the morning after each night.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                ForEach(nights) { night in
                    nightPill(night)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard(cornerRadius: 28)
    }

    private func nightPill(_ night: NightPlan) -> some View {
        let isOn = night.isEnabled && night.alarmEnabled
        let day = night.weekday
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return VStack(spacing: 6) {
            Text(day.initial)
                .font(.system(.headline, design: .rounded, weight: .heavy))

            if isOn {
                Text(night.wakeMinutes.compactClockText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text(verbatim: "–")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
        }
        .foregroundStyle(isOn ? Color.midnightNavy : Color.white.opacity(0.4))
        .frame(maxWidth: .infinity, minHeight: 60)
        .background {
            if isOn {
                shape
                    .fill(NightGradient.lavender)
                    .overlay {
                        shape.strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                    }
                    .shadow(color: Color.dreamPurple.opacity(0.5), radius: 10, y: 4)
            } else {
                shape
                    .fill(Color.white.opacity(0.04))
                    .overlay {
                        shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: day.fullName))
        .accessibilityValue(isOn ? Text(verbatim: night.wakeMinutes.clockText) : Text("No alarm"))
    }

    // MARK: - Snooze

    private var snoozeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Snooze")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text("How long you get before it rings again.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(snoozeRows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(snoozeRows[row], id: \.self) { minutes in
                            snoozeTile(minutes)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard(cornerRadius: 28)
        .sensoryFeedback(.selection, trigger: plan.snoozeMinutes)
    }

    private func snoozeTile(_ minutes: Int) -> some View {
        let isSelected = plan.snoozeMinutes == minutes
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return Button {
            withAnimation(.snappy) { plan.snoozeMinutes = minutes }
        } label: {
            VStack(spacing: 1) {
                if minutes == 0 {
                    Text("Off")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                } else {
                    Text("\(minutes)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text("min")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                }
            }
            .foregroundStyle(isSelected ? Color.midnightNavy : Color.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                if isSelected {
                    shape
                        .fill(NightGradient.lavender)
                        .overlay {
                            shape.strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                        }
                        .shadow(color: Color.dreamPurple.opacity(0.5), radius: 8, y: 3)
                } else {
                    shape
                        .fill(Color.white.opacity(0.07))
                        .overlay {
                            shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    ZStack {
        NightBackground()
        AlarmSetupView(plan: preview.plan, isActive: true)
            .padding()
    }
    .modelContainer(preview.container)
}
