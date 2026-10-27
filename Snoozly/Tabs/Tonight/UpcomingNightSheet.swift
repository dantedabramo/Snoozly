//
//  UpcomingNightSheet.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-26.
//

import SwiftUI
import SwiftData

// MARK: - UpcomingNightSheet

struct UpcomingNightSheet: View {
    let night: NightPlan?
    let plan: SleepPlan?
    let date: Date
    let isTonight: Bool
    let isSkipped: Bool
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var permissions = PermissionCenter.shared
    @ScaledMetric(relativeTo: .largeTitle) private var heroTimeSize: CGFloat = 48

    private var isOn: Bool {
        night?.isEnabled == true
    }

    private var eyebrow: LocalizedStringKey {
        isTonight ? "Tonight" : "Upcoming Night"
    }

    private var dateText: String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var windDownMinutes: Int {
        plan?.windDownMinutes ?? 30
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            NightBackground(mood: .tonight)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar

                    heroCard

                    if let night, isOn {
                        detailsCard(for: night)
                    }

                    editButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .presentationDetents([.fraction(0.78), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow)
                    .font(.system(.footnote, design: .rounded, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(Color.starlightGold)

                Text(dateText)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer(minLength: 8)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.lavendar)
                    .frame(width: 40, height: 40)
                    .nightCard(cornerRadius: 20, blurs: false)
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 12, weight: .bold))

                        Text("Bedtime")
                            .font(.system(.footnote, design: .rounded, weight: .heavy))
                            .textCase(.uppercase)
                            .tracking(1.2)
                    }
                    .foregroundStyle(Color.starlightGold)

                    Text(isOn ? (night?.bedtimeMinutes ?? 0).clockText : "Off")
                        .font(.system(size: heroTimeSize, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(NightGradient.title)
                        .shadow(color: Color.dreamPurple.opacity(0.55), radius: 14)
                }

                Spacer(minLength: 4)

                SleepyCreatureView(showStars: true)
                    .frame(width: 96, height: 96)
                    .offset(y: -4)
            }

            if let night, isOn {
                sleepTimeline(night: night)
            } else {
                Text("No bedtime scheduled for this night.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.75))
            }

            if isSkipped {
                InfoChip(icon: "moon.zzz.fill", text: "Skipped Tonight", tint: Color.starlightGold)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            GlowOrb(color: Color.dreamPurple, opacity: 0.55, diameter: 300)
                .offset(x: 90, y: -90)
        }
        .clipShape(shape)
        .nightCard(cornerRadius: 32, tint: Color.dreamPurple, elevated: true)
        .accessibilityElement(children: .combine)
    }

    private func sleepTimeline(night: NightPlan) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.lavendar)

            Capsule()
                .fill(NightGradient.night)
                .frame(height: 5)
                .shadow(color: Color.dreamPurple.opacity(0.6), radius: 6)
                .overlay {
                    Text(night.sleepMinutes.durationText)
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.midnightNavy))
                        .overlay {
                            Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                        }
                }

            Image(systemName: "sunrise.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.starlightGold)

            Text(night.wakeMinutes.clockText)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }

    // MARK: - Details

    private func detailsCard(for night: NightPlan) -> some View {
        VStack(spacing: 14) {
            SettingsRow(
                icon: "wind",
                title: "Wind Down",
                subtitle: "\(windDownStart(for: night).clockText) · \(windDownMinutes) min before bed",
                tint: Color.moonlightBlue
            )

            RowDivider()

            SettingsRow(icon: "alarm.fill", title: "Wake-up Alarm", subtitle: alarmSubtitle(for: night), tint: Color.starlightGold) {
                StatusCapsule(kind: capsuleKind(isOn: night.alarmEnabled, isWorking: permissions.alarms == .granted))
            }

            RowDivider()

            SettingsRow(
                icon: "hourglass",
                title: "Quiet Apps",
                subtitle: quietAppsSubtitle(for: night),
                tint: Color.moonlightBlue
            ) {
                StatusCapsule(kind: capsuleKind(isOn: night.quietAppsEnabled, isWorking: permissions.quietAppsReady(for: plan)))
            }

            RowDivider()

            SettingsRow(
                icon: "bell.badge.fill",
                title: "Bedtime Reminders",
                subtitle: remindersSubtitle(for: night),
                tint: Color.dreamCoral
            ) {
                StatusCapsule(kind: capsuleKind(isOn: night.remindersEnabled, isWorking: permissions.remindersActive(for: plan)))
            }
        }
        .padding(16)
        .nightCard(cornerRadius: 26)
    }

    private func windDownStart(for night: NightPlan) -> Int {
        (night.bedtimeMinutes - windDownMinutes + 24 * 60) % (24 * 60)
    }

    private func capsuleKind(isOn: Bool, isWorking: Bool) -> StatusCapsule.Kind {
        guard isOn else { return .off }
        return isWorking ? .on : .setUp
    }

    private func quietAppsSubtitle(for night: NightPlan) -> LocalizedStringKey? {
        guard night.quietAppsEnabled else { return nil }
        guard permissions.quietAppsReady(for: plan) else { return "Paused until Screen Time and apps are set up" }
        return "\(windDownStart(for: night).clockText) until wake-up"
    }

    private func remindersSubtitle(for night: NightPlan) -> LocalizedStringKey? {
        guard night.remindersEnabled else { return nil }
        guard permissions.remindersActive(for: plan) else { return "Paused until notifications are allowed" }
        return "At wind-down and at bedtime"
    }

    private func alarmSubtitle(for night: NightPlan) -> LocalizedStringKey? {
        guard night.alarmEnabled else { return nil }
        guard permissions.alarms == .granted else { return "Paused until alarms are allowed" }

        let wake = night.wakeMinutes.clockText
        let snooze = plan?.effectiveSnoozeMinutes(for: night) ?? 0

        if snooze > 0 {
            return "\(wake) · snooze \(snooze) min"
        }
        return "\(wake) · no snooze"
    }

    // MARK: - Edit

    private var editButton: some View {
        Button(action: onEdit) {
            Label("Edit in Schedule", systemImage: "calendar")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Color.midnightNavy)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Capsule().fill(NightGradient.lavender))
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                }
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    UpcomingNightSheet(
        night: preview.plan.sortedNights.first,
        plan: preview.plan,
        date: .now,
        isTonight: false,
        isSkipped: false,
        onEdit: {}
    )
    .modelContainer(preview.container)
}
