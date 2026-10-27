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

    @State private var permissions = PermissionCenter.shared
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
            await permissions.refresh()
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

            Label("Pick the night you go to bed. You wake up the next morning. Press and hold to copy across days.", systemImage: "hand.tap.fill")
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

    private func cardHeader(icon: String, title: String, subtitle: String? = nil, isActive: Bool, tint: Color) -> some View {
        HStack(spacing: 12) {
            RowIcon(systemName: icon, size: 40, tint: isActive ? tint : Color.white.opacity(0.4))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.lavendar.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

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
            cardHeader(
                icon: "sunrise.fill",
                title: "\(morningDay.fullName) Morning",
                subtitle: "After \(night.weekday.fullName) night",
                isActive: night.isEnabled,
                tint: Color.starlightGold
            )

            if night.isEnabled {
                VStack(spacing: 12) {
                    timeHeader(night.wakeMinutes, label: "Wake-up", labelColor: Color.starlightGold)
                    timeWheel(minutes: Bindable(night).wakeMinutes)
                    sleepSummary(for: night)

                    VStack(spacing: 10) {
                        optionRow(icon: "alarm.fill", title: "Wake-up Alarm", tint: Color.starlightGold) {
                            Toggle(isOn: alarmBinding(for: night)) {
                                Text("Wake-up Alarm")
                            }
                            .labelsHidden()
                            .tint(Color.dreamPurple)
                        }

                        if night.alarmEnabled && permissions.alarms != .granted {
                            AccessNotice(
                                message: alarmNoticeMessage,
                                actionTitle: PermissionKind.alarms.actionTitle(for: permissions.alarms)
                            ) {
                                Task {
                                    await permissions.allowAlarms(for: plan)
                                }
                            }
                        }

                        if night.alarmEnabled {
                            snoozeRow(for: night)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            } else {
                Text("No wake-up set for \(morningDay.fullName) morning.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.65))
                    .padding(.vertical, 4)
            }
        }
        .padding(18)
        .nightCard(cornerRadius: 28)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: night.isEnabled)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: night.alarmEnabled)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: permissions.alarms)
    }

    private var alarmNoticeMessage: LocalizedStringKey {
        switch permissions.alarms {
        case .denied: "Alarms are off for Snoozly, so this alarm won't ring."
        case .failed: "Couldn't confirm alarm access, so this alarm may not ring."
        case .notDetermined: "Allow alarms so this one can ring."
        case .granted: ""
        }
    }

    private func alarmBinding(for night: NightPlan) -> Binding<Bool> {
        Binding(
            get: { night.alarmEnabled },
            set: { newValue in
                night.alarmEnabled = newValue
                if newValue, permissions.alarms == .notDetermined || permissions.alarms == .failed {
                    Task {
                        await permissions.allowAlarms(for: plan)
                    }
                }
            }
        )
    }

    private func sleepSummary(for night: NightPlan) -> some View {
        let sleep = night.sleepMinutes
        let difference = sleep - sleepGoalMinutes
        let goalText = sleepGoalMinutes.durationText

        let icon: String
        let tint: Color
        let detail: LocalizedStringKey

        if difference < -15 {
            icon = "exclamationmark.triangle.fill"
            tint = Color.dreamCoral
            detail = "\((-difference).durationText) short of your \(goalText) goal"
        } else if difference > 120 {
            icon = "moon.zzz.fill"
            tint = Color.lavendar
            detail = "\(difference.durationText) over your \(goalText) goal"
        } else if difference > 15 {
            icon = "checkmark.seal.fill"
            tint = Color.restfulMint
            detail = "Meets your \(goalText) goal with \(difference.durationText) to spare"
        } else {
            icon = "checkmark.seal.fill"
            tint = Color.restfulMint
            detail = "Right on your \(goalText) goal"
        }

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint.opacity(0.16)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(sleep.durationText) of sleep")
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(tint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
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
        if permissions.isPreparingScreenTime { return "Opening Screen Time…" }

        let count = ScreenTimeService.selectionCount(for: plan)

        guard permissions.screenTime == .granted else {
            return count == 0 ? "Needs Screen Time access" : "\(count) selected · needs Screen Time access"
        }
        return count == 0 ? "Tap to choose apps" : "\(count) selected · tap to change"
    }

    private var reminderSubtitle: LocalizedStringKey {
        switch permissions.notifications {
        case .granted:
            return plan?.notificationsEnabled == true ? "At wind-down and at bedtime" : "Tap to turn on"
        case .denied:
            return "Notifications are off · tap to open Settings"
        case .notDetermined, .failed:
            return "Tap to allow notifications"
        }
    }

    private var quietAppsNoticeMessage: LocalizedStringKey {
        switch permissions.screenTime {
        case .granted: "No apps are chosen yet, so nothing will be quieted."
        case .denied: "Screen Time access was declined, so no apps will be quieted."
        case .failed: "Screen Time isn't available right now, so no apps will be quieted."
        case .notDetermined: "Allow Screen Time so Snoozly can quiet your apps."
        }
    }

    private var quietAppsNoticeAction: LocalizedStringKey {
        permissions.screenTime == .granted ? "Choose" : PermissionKind.screenTime.actionTitle(for: permissions.screenTime)
    }

    private var remindersNoticeMessage: LocalizedStringKey {
        switch permissions.notifications {
        case .granted: "Reminders are paused, so nothing will arrive."
        case .denied: "Notifications are off for Snoozly, so nothing will arrive."
        case .notDetermined, .failed: "Allow notifications so reminders can arrive."
        }
    }

    private var remindersNoticeAction: LocalizedStringKey {
        permissions.notifications == .granted ? "Turn On" : PermissionKind.notifications.actionTitle(for: permissions.notifications)
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
                        chooseQuietApps()
                    } label: {
                        SettingsRow(icon: "hourglass", title: "Quiet Apps", subtitle: quietAppsSubtitle, tint: Color.moonlightBlue)
                    }
                    .buttonStyle(.plain)

                    Toggle(isOn: Binding(
                        get: { night.quietAppsEnabled },
                        set: { newValue in
                            night.quietAppsEnabled = newValue
                            if newValue, permissions.screenTime != .denied, !permissions.quietAppsReady(for: plan) {
                                chooseQuietApps()
                            }
                        }
                    )) {
                        Text("Quiet Apps")
                    }
                    .labelsHidden()
                    .tint(Color.dreamPurple)
                }

                if night.quietAppsEnabled && !permissions.quietAppsReady(for: plan) {
                    AccessNotice(
                        message: quietAppsNoticeMessage,
                        actionTitle: quietAppsNoticeAction,
                        isBusy: permissions.isPreparingScreenTime
                    ) {
                        chooseQuietApps()
                    }
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
                            if newValue, permissions.notifications != .denied, !permissions.remindersActive(for: plan) {
                                enableReminders()
                            }
                        }
                    )) {
                        Text("Bedtime Reminders")
                    }
                    .labelsHidden()
                    .tint(Color.dreamPurple)
                }

                if night.remindersEnabled && !permissions.remindersActive(for: plan) {
                    AccessNotice(
                        message: remindersNoticeMessage,
                        actionTitle: remindersNoticeAction
                    ) {
                        enableReminders()
                    }
                }
            }
        }
        .padding(18)
        .nightCard(cornerRadius: 28)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: permissions.screenTime)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: permissions.notifications)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: night.quietAppsEnabled)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: night.remindersEnabled)
    }

    // MARK: - Setup Actions

    private func enableReminders() {
        Task {
            await permissions.allowNotifications(for: plan)
        }
    }

    private func chooseQuietApps() {
        Task {
            if await permissions.allowScreenTime() {
                showQuietPicker = true
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
