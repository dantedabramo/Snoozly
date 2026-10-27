//
//  ScheduleView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-12.
//

import SwiftUI
import SwiftData

// MARK: - ScheduleView

struct ScheduleView: View {
    @Query private var plans: [SleepPlan]
    @Binding var selectedWeekday: Weekday
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKey.sleepGoalMinutes) private var sleepGoalMinutes = 480

    @State private var reminderAccess: NotificationManager.Access = .notDetermined
    @State private var showQuietPicker = false
    @State private var appeared = false
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize: CGFloat = 40

    private var plan: SleepPlan? {
        plans.first
    }

    private var nights: [NightPlan] {
        plan?.sortedNights ?? []
    }

    private var selectedNight: NightPlan? {
        nights.first { $0.weekday == selectedWeekday }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            NightBackground(mood: .schedule)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                        .reveal(appeared, delay: 0)

                    daySelectorSection
                        .reveal(appeared, delay: 0.05)

                    if let night = selectedNight {
                        bedtimeCard(for: night)
                            .reveal(appeared, delay: 0.10)

                        wakeUpCard(for: night)
                            .reveal(appeared, delay: 0.15)

                        windDownCard(for: night)
                            .reveal(appeared, delay: 0.20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, 24, for: .scrollContent)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
        }
        .revealOnAppear($appeared)
        .quietAppsPicker(for: plan, isPresented: $showQuietPicker)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            reminderAccess = await NotificationManager.shared.access()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ScreenHeader("Schedule", subtitle: "Shape every night of your week.")
    }

    // MARK: - Day Selector

    private var daySelectorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            WeekStrip(nights: nights, selection: $selectedWeekday)
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 22, style: .continuous))
                .contextMenu {
                    Button {
                        copyCurrent(to: Set(Weekday.allCases))
                    } label: {
                        Label("Copy This Schedule to All Days", systemImage: "doc.on.doc")
                    }

                    Button {
                        copyCurrent(to: [.monday, .tuesday, .wednesday, .thursday, .friday])
                    } label: {
                        Label("Copy to Weekdays (Mon-Fri)", systemImage: "briefcase")
                    }

                    Button {
                        copyCurrent(to: [.saturday, .sunday])
                    } label: {
                        Label("Copy to Weekends (Sat-Sun)", systemImage: "sun.max")
                    }
                } preview: {
                    WeekStrip(nights: nights, selection: .constant(selectedWeekday), showsGlow: false)
                        .padding(10)
                        .frame(width: 350)
                        .background(Color.midnightNavy)
                }

            Label("Select a day to edit it. Press and hold to copy across days.", systemImage: "hand.tap.fill")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.lavendar.opacity(0.7))
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Time Display

    private func timeHeader(_ minutes: Int, label: LocalizedStringKey, labelColor: Color) -> some View {
        HStack {
            Text(minutes.clockText)
                .font(.system(size: timeSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(NightGradient.title)
                .shadow(color: Color.dreamPurple.opacity(0.5), radius: 12)
                .contentTransition(.numericText())

            Spacer()

            Text(label)
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(labelColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(labelColor.opacity(0.14)))
                .overlay {
                    Capsule().strokeBorder(labelColor.opacity(0.3), lineWidth: 1)
                }
        }
    }

    private func timeWheel(minutes: Binding<Int>) -> some View {
        DatePicker(
            "",
            selection: Binding(
                get: { Date.today(atMinutes: minutes.wrappedValue) },
                set: { minutes.wrappedValue = $0.minutesAfterMidnight }
            ),
            displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .environment(\.colorScheme, .dark)
        .frame(height: 104)
        .clipped()
        .padding(.vertical, 4)
    }

    private func cardHeader(icon: String, title: String, isActive: Bool, tint: Color) -> some View {
        HStack(spacing: 12) {
            RowIcon(systemName: icon, size: 40, tint: isActive ? tint : Color.white.opacity(0.4))

            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 8)
        }
    }

    // MARK: - Bedtime Card

    private func bedtimeCard(for night: NightPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                cardHeader(icon: "moon.stars.fill", title: "\(night.weekday.fullName) Night", isActive: night.isEnabled, tint: Color.lavendar)

                Toggle(isOn: Bindable(night).isEnabled) {
                    Text("Enable this night")
                }
                .labelsHidden()
                .tint(Color.dreamPurple)
            }

            if night.isEnabled {
                VStack(spacing: 12) {
                    timeHeader(night.bedtimeMinutes, label: "Bedtime", labelColor: Color.lavendar)
                    timeWheel(minutes: Bindable(night).bedtimeMinutes)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            } else {
                Text("No bedtime scheduled for this night.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.65))
                    .padding(.vertical, 4)
            }
        }
        .padding(18)
        .nightCard(cornerRadius: 28)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: night.isEnabled)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contextMenu {
            Button {
                copyCurrent(to: Set(Weekday.allCases))
            } label: {
                Label("Copy Bedtime to All Days", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - Wake-Up Card

    private func wakeUpCard(for night: NightPlan) -> some View {
        let morningDay = night.weekday.shifted(by: 1)

        return VStack(alignment: .leading, spacing: 16) {
            cardHeader(icon: "sunrise.fill", title: "\(night.weekday.fullName) Wake-up", isActive: night.isEnabled, tint: Color.starlightGold)

            if night.isEnabled {
                VStack(spacing: 12) {
                    timeHeader(night.wakeMinutes, label: "Wake-up", labelColor: Color.starlightGold)
                    timeWheel(minutes: Bindable(night).wakeMinutes)
                    sleepSummary(for: night)

                    VStack(spacing: 10) {
                        optionRow(icon: "alarm.fill", title: "Wake-up Alarm", tint: Color.starlightGold) {
                            Toggle(isOn: Bindable(night).alarmEnabled) {
                                Text("Wake-up Alarm")
                            }
                            .labelsHidden()
                            .tint(Color.dreamPurple)
                        }

                        if night.alarmEnabled {
                            snoozeRow(for: night)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            } else {
                Text("No wake-up alarm or schedule for this morning.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.65))
                    .padding(.vertical, 4)
            }
        }
        .padding(18)
        .nightCard(cornerRadius: 28)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: night.isEnabled)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: night.alarmEnabled)
    }

    private func sleepSummary(for night: NightPlan) -> some View {
        let meetsGoal = night.sleepMinutes >= sleepGoalMinutes - 15
        let tint = meetsGoal ? Color.restfulMint : Color.dreamCoral
        let text = meetsGoal
            ? "\(night.sleepMinutes.durationText) of sleep · meets your goal"
            : "\(night.sleepMinutes.durationText) of sleep · under your \(sleepGoalMinutes.durationText) goal"

        return HStack(spacing: 8) {
            Image(systemName: meetsGoal ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .bold))

            Text(text)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.12))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func snoozeRow(for night: NightPlan) -> some View {
        let length = plan?.snoozeMinutes ?? 0
        let hasLength = length > 0

        let subtitle: LocalizedStringKey
        if hasLength {
            subtitle = "\(length) min · change the length in Settings"
        } else {
            subtitle = "Choose a snooze length in Settings first"
        }

        return optionRow(icon: "zzz", title: "Snooze", subtitle: subtitle, tint: Color.lavendar) {
            Toggle(isOn: Binding(
                get: { night.snoozeEnabled && hasLength },
                set: { night.snoozeEnabled = $0 }
            )) {
                Text("Snooze")
            }
            .labelsHidden()
            .tint(Color.dreamPurple)
            .disabled(!hasLength)
        }
    }

    private func optionRow<Trailing: View>(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        tint: Color = Color.starlightGold,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        SettingsRow(icon: icon, title: title, subtitle: subtitle, tint: tint, trailing: trailing)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .nightWell(cornerRadius: 18)
    }

    // MARK: - Wind Down Card

    private var quietAppsSubtitle: LocalizedStringKey {
        guard let plan else { return "Choose apps to quiet" }
        if ScreenTimeService.isReady(for: plan) {
            return "\(ScreenTimeService.selectionCount(for: plan)) selected · tap to change"
        }
        return "Tap to choose apps"
    }

    private var reminderSubtitle: LocalizedStringKey {
        switch reminderAccess {
        case .allowed:
            return plan?.notificationsEnabled == true ? "At wind-down and at bedtime" : "Tap to turn on"
        case .denied:
            return "Notifications are off · tap to open Settings"
        case .notDetermined:
            return "Tap to allow notifications"
        }
    }

    private func windDownCard(for night: NightPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "wind")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.moonlightBlue)

                Text("Wind Down")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Button {
                        chooseQuietApps(for: night)
                    } label: {
                        SettingsRow(icon: "hourglass", title: "Quiet Apps", subtitle: quietAppsSubtitle, tint: Color.moonlightBlue)
                    }
                    .buttonStyle(.plain)

                    Toggle(isOn: Binding(
                        get: { night.quietAppsEnabled },
                        set: { newValue in
                            night.quietAppsEnabled = newValue
                            if newValue, let plan, !ScreenTimeService.isReady(for: plan) {
                                chooseQuietApps(for: night)
                            }
                        }
                    )) {
                        Text("Quiet Apps")
                    }
                    .labelsHidden()
                    .tint(Color.dreamPurple)
                }

                RowDivider()

                HStack(spacing: 8) {
                    Button {
                        enableReminders()
                    } label: {
                        SettingsRow(icon: "bell.badge.fill", title: "Bedtime Reminders", subtitle: reminderSubtitle, tint: Color.dreamCoral)
                    }
                    .buttonStyle(.plain)

                    Toggle(isOn: Binding(
                        get: { night.remindersEnabled },
                        set: { newValue in
                            night.remindersEnabled = newValue
                            if newValue, !(plan?.notificationsEnabled == true && reminderAccess == .allowed) {
                                enableReminders()
                            }
                        }
                    )) {
                        Text("Bedtime Reminders")
                    }
                    .labelsHidden()
                    .tint(Color.dreamPurple)
                }
            }
        }
        .padding(18)
        .nightCard(cornerRadius: 28)
    }

    // MARK: - Setup Actions

    private func enableReminders() {
        guard let plan else { return }
        Task {
            await NotificationManager.shared.turnOnReminders(for: plan)
            reminderAccess = await NotificationManager.shared.access()
        }
    }

    private func chooseQuietApps(for night: NightPlan) {
        Task {
            if await ScreenTimeService.prepareForPicker() {
                showQuietPicker = true
            } else {
                night.quietAppsEnabled = false
            }
        }
    }

    // MARK: - Copy Actions

    private func copyCurrent(to days: Set<Weekday>) {
        guard let current = selectedNight else { return }

        for night in nights where days.contains(night.weekday) {
            night.bedtimeMinutes = current.bedtimeMinutes
            night.wakeMinutes = current.wakeMinutes
            night.isEnabled = current.isEnabled
            night.alarmEnabled = current.alarmEnabled
            night.snoozeEnabled = current.snoozeEnabled
            night.quietAppsEnabled = current.quietAppsEnabled
            night.remindersEnabled = current.remindersEnabled
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - WeekStrip

private struct WeekStrip: View {
    let nights: [NightPlan]
    @Binding var selection: Weekday
    var showsGlow: Bool = true

    @Namespace private var highlight
    @State private var taps = 0

    private let today = Weekday.today

    var body: some View {
        HStack(spacing: 6) {
            ForEach(nights) { night in
                dayChip(for: night)
            }
        }
        .sensoryFeedback(.selection, trigger: taps)
    }

    private func dayChip(for night: NightPlan) -> some View {
        let day = night.weekday
        let isSelected = day == selection
        let isToday = day == today
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return Button {
            taps += 1
            withAnimation(.spring(response: 0.45, dampingFraction: 0.74)) {
                selection = day
            }
        } label: {
            VStack(spacing: 6) {
                Text(day.initial)
                    .font(.system(.headline, design: .rounded, weight: .heavy))

                Text(night.isEnabled ? night.bedtimeMinutes.compactClockText : "Off")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(0.9)

                Circle()
                    .fill(isSelected ? Color.midnightNavy : Color.starlightGold)
                    .frame(width: 4, height: 4)
                    .opacity(isToday ? 1 : 0)
            }
            .foregroundStyle(foreground(isSelected: isSelected, isEnabled: night.isEnabled))
            .frame(maxWidth: .infinity, minHeight: 70)
            .background {
                ZStack {
                    shape
                        .fill(Color.white.opacity(night.isEnabled ? 0.07 : 0.03))
                        .overlay {
                            shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }

                    if isSelected {
                        shape
                            .fill(NightGradient.lavender)
                            .overlay {
                                shape.strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                            }
                            .shadow(color: Color.dreamPurple.opacity(showsGlow ? 0.5 : 0), radius: showsGlow ? 10 : 0, y: showsGlow ? 4 : 0)
                            .matchedGeometryEffect(id: "highlight", in: highlight)
                    }
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(Text(verbatim: day.fullName))
        .accessibilityValue(night.isEnabled ? Text(verbatim: night.bedtimeMinutes.compactClockText) : Text("Off"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func foreground(isSelected: Bool, isEnabled: Bool) -> Color {
        if isSelected { return Color.midnightNavy }
        return isEnabled ? Color.white : Color.white.opacity(0.4)
    }
}

#Preview {
    @Previewable @State var weekday = Weekday.today
    let preview = PreviewSleepPlan()

    ScheduleView(selectedWeekday: $weekday)
        .modelContainer(preview.container)
}
