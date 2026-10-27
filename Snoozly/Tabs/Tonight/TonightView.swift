//
//  TonightView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-12.
//

import SwiftUI
import SwiftData

// MARK: - TonightView

struct TonightView: View {
    var onShowSchedule: ((Weekday?) -> Void)? = nil

    @Query private var plans: [SleepPlan]
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKey.profileName) private var profileName = ""
    @AppStorage(AppStorageKey.skipDateString) private var skipDateString = ""
    @State private var proManager = ProManager.shared
    @State private var showProSheet = false
    @State private var showScheduleSheet = false
    @State private var upcomingSelection: UpcomingSelection?
    @State private var showQuietPicker = false
    @State private var sheetWeekday: Weekday = .today
    @State private var permissions = PermissionCenter.shared
    @State private var appeared = false
    @ScaledMetric(relativeTo: .largeTitle) private var heroTimeSize: CGFloat = 48

    private let gutter: CGFloat = 20

    private struct UpcomingSelection: Identifiable {
        let dayOffset: Int

        var id: Int { dayOffset }
    }

    private var plan: SleepPlan? {
        plans.first
    }

    private var tonightWeekday: Weekday {
        Weekday(date: Calendar.current.date(byAdding: .hour, value: -6, to: .now) ?? .now)
    }

    private var isTonightSkipped: Bool {
        skipDateString == TonightSkip.nightKey
    }

    private func setSkipped(_ skipped: Bool) {
        skipDateString = skipped ? TonightSkip.nightKey : ""
    }

    private func showSchedule(_ weekday: Weekday? = nil) {
        if let onShowSchedule {
            onShowSchedule(weekday)
        } else {
            sheetWeekday = weekday ?? tonightWeekday
            showScheduleSheet = true
        }
    }

    private var tonightNight: NightPlan? {
        plan?.sortedNights.first { $0.weekday == tonightWeekday }
    }

    private enum RowStatus {
        case on
        case off
        case needsSetup
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let baseGreeting: String
        if hour < 12 {
            baseGreeting = "Good Morning"
        } else if hour < 17 {
            baseGreeting = "Good Afternoon"
        } else {
            baseGreeting = "Good Evening"
        }

        let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return baseGreeting
        } else {
            return "\(baseGreeting), \(trimmedName)"
        }
    }

    private var formattedDate: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var windDownCountdown: String {
        guard let tonight = tonightNight, tonight.isEnabled, !isTonightSkipped else {
            return "No Wind Down"
        }
        let windDownMinutes = tonight.bedtimeMinutes - (plan?.windDownMinutes ?? 30)
        let nowMinutes = Date.now.minutesAfterMidnight
        var diff = windDownMinutes - nowMinutes
        if diff < 0 {
            diff += 24 * 60
        }
        let hours = diff / 60
        let mins = diff % 60
        if hours > 0 {
            return "Wind Down in \(hours)h \(mins)min"
        } else {
            return "Wind Down in \(mins)min"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            NightBackground(mood: .tonight)

            ScrollView {
                TimelineView(.everyMinute) { _ in
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                            .padding(.horizontal, gutter)
                            .reveal(appeared, delay: 0)

                        heroCard
                            .padding(.horizontal, gutter)
                            .reveal(appeared, delay: 0.06)

                        holdToSkipButton
                            .padding(.horizontal, gutter)
                            .reveal(appeared, delay: 0.12)

                        remindersAndAlarmsSection
                            .padding(.horizontal, gutter)
                            .reveal(appeared, delay: 0.18)

                        upcomingNightsSection
                            .reveal(appeared, delay: 0.24)
                    }
                    .padding(.vertical, 16)
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, 24, for: .scrollContent)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
        }
        .revealOnAppear($appeared)
        .sheet(isPresented: $showProSheet) {
            ProSheetView()
        }
        .sheet(isPresented: $showScheduleSheet) {
            ScheduleView(selectedWeekday: $sheetWeekday)
        }
        .sheet(item: $upcomingSelection) { selection in
            upcomingSheet(for: selection.dayOffset)
        }
        .quietAppsPicker(for: plan, isPresented: $showQuietPicker)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await permissions.refresh()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(formattedDate)
                .font(.system(.footnote, design: .rounded, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(Color.starlightGold)

            Text(greetingText)
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        let night = tonightNight
        let isOn = night?.isEnabled == true

        return ZStack {
            heroContent(night: night, isOn: isOn)
                .opacity(isTonightSkipped ? 0.4 : 1.0)
                .grayscale(isTonightSkipped ? 0.8 : 0.0)

            if isTonightSkipped {
                Label("Skipped Tonight", systemImage: "moon.zzz.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color.midnightNavy)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(NightGradient.gold))
                    .shadow(color: Color.starlightGold.opacity(0.4), radius: 14, y: 4)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isTonightSkipped)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 32, style: .continuous))
        .contextMenu {
            Button {
                withAnimation(.snappy) {
                    setSkipped(!isTonightSkipped)
                }
            } label: {
                Label(isTonightSkipped ? "Resume Tonight" : "Skip Tonight", systemImage: isTonightSkipped ? "arrow.counterclockwise" : "moon.zzz.fill")
            }

            Button {
                showSchedule()
            } label: {
                Label("Edit Schedule", systemImage: "calendar")
            }
        }
    }

    private func heroContent(night: NightPlan?, isOn: Bool) -> some View {
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
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 4)

                SleepyCreatureView(showStars: true)
                    .frame(width: 112, height: 112)
                    .offset(y: -6)
            }

            if let night, isOn {
                sleepTimeline(night: night)
            } else {
                Text("No bedtime scheduled for tonight.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.75))
            }

            HStack(spacing: 8) {
                InfoChip(icon: "clock.fill", text: windDownCountdown, tint: Color.starlightGold)

                if let night, isOn, night.alarmEnabled, permissions.alarms == .granted {
                    InfoChip(icon: "alarm.fill", text: "Alarm \(night.wakeMinutes.clockText)", tint: Color.lavendar)
                } else if let night, isOn, night.alarmEnabled {
                    InfoChip(icon: "exclamationmark.circle.fill", text: "Alarm needs access", tint: Color.dreamCoral)
                } else {
                    InfoChip(icon: "alarm", text: "No Alarm", tint: Color.lavendar.opacity(0.6))
                }

                Spacer(minLength: 0)
            }
        }
        .padding(22)
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

    // MARK: - Hold to Skip Button

    private var holdToSkipButton: some View {
        HoldActionButton(
            title: isTonightSkipped ? "Hold to Resume Tonight" : "Hold to Skip Tonight",
            systemImage: isTonightSkipped ? "arrow.counterclockwise" : "moon.zzz.fill",
            isHighlighted: isTonightSkipped
        ) {
            withAnimation(.snappy) {
                setSkipped(!isTonightSkipped)
            }
        }
    }

    // MARK: - Reminders & Alarms

    private var remindersAndAlarmsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Reminders and Alarms")

            VStack(spacing: 14) {
                quietAppsRow
                RowDivider()
                alarmRow
                RowDivider()
                bedtimeRemindersRow
                RowDivider()
                changeScheduleRow
            }
            .padding(16)
            .nightCard(cornerRadius: 26)
        }
    }

    private func statusRow(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey?,
        tint: Color,
        status: RowStatus,
        isTappable: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let kind: StatusCapsule.Kind = switch status {
        case .on: .on
        case .off: .off
        case .needsSetup: .setUp
        }

        let row = SettingsRow(icon: icon, title: title, subtitle: subtitle, tint: tint) {
            StatusCapsule(kind: kind)
        }

        return Group {
            if isTappable {
                Button(action: action) { row }
                    .buttonStyle(PressScaleButtonStyle())
            } else {
                row
            }
        }
    }

    // MARK: Status

    private var quietAppsStatus: RowStatus {
        guard let night = tonightNight, night.isEnabled, night.quietAppsEnabled, !isTonightSkipped else { return .off }
        return permissions.quietAppsReady(for: plan) ? .on : .needsSetup
    }

    private var alarmStatus: RowStatus {
        guard let night = tonightNight, night.isEnabled, night.alarmEnabled, !isTonightSkipped else { return .off }
        return permissions.alarms == .granted ? .on : .needsSetup
    }

    private var remindersStatus: RowStatus {
        guard let night = tonightNight, night.isEnabled, night.remindersEnabled, !isTonightSkipped else { return .off }
        return permissions.remindersActive(for: plan) ? .on : .needsSetup
    }

    // MARK: Rows

    private var quietAppsRow: some View {
        let subtitle: LocalizedStringKey? = quietAppsSubtitle

        return statusRow(
            icon: "hourglass",
            title: "Quiet Apps",
            subtitle: subtitle,
            tint: Color.moonlightBlue,
            status: quietAppsStatus,
            isTappable: quietAppsStatus == .needsSetup,
            action: chooseQuietApps
        )
    }

    private var quietAppsSubtitle: LocalizedStringKey? {
        if permissions.isPreparingScreenTime {
            return "Opening Screen Time…"
        }
        if quietAppsStatus == .needsSetup {
            switch permissions.screenTime {
            case .granted: return "Tap to choose the apps to quiet"
            case .notDetermined: return "Tap to allow Screen Time and choose apps"
            case .denied: return "Screen Time access was declined. Tap to try again."
            case .failed: return "Screen Time isn't available right now. Tap to retry."
            }
        }
        guard let tonight = tonightNight, tonight.isEnabled, let plan else { return nil }
        let startMinutes = (tonight.bedtimeMinutes - plan.windDownMinutes + 24 * 60) % (24 * 60)
        return "\(startMinutes.clockText) until wake-up"
    }

    private var alarmRow: some View {
        let subtitle: LocalizedStringKey? = alarmSubtitle

        return statusRow(
            icon: "alarm.fill",
            title: "Wake-up Alarm",
            subtitle: subtitle,
            tint: Color.starlightGold,
            status: alarmStatus,
            isTappable: alarmStatus == .needsSetup,
            action: allowAlarms
        )
    }

    private var alarmSubtitle: LocalizedStringKey? {
        if alarmStatus == .needsSetup {
            switch permissions.alarms {
            case .notDetermined: return "Tap to allow alarms"
            case .denied: return "Alarms are off for Snoozly, so it won't ring. Tap to open Settings."
            case .failed: return "Couldn't confirm alarm access. Tap to retry."
            case .granted: return nil
            }
        }
        guard let tonight = tonightNight, tonight.isEnabled, tonight.alarmEnabled else { return nil }

        let minutes = tonight.wakeMinutes.clockText
        guard let plan, plan.effectiveSnoozeMinutes(for: tonight) > 0 else {
            return "\(minutes) · no snooze"
        }
        return "\(minutes) · snooze \(plan.effectiveSnoozeMinutes(for: tonight)) min"
    }

    private var bedtimeRemindersRow: some View {
        let subtitle: LocalizedStringKey? = remindersSubtitle

        return statusRow(
            icon: "bell.badge.fill",
            title: "Bedtime Reminders",
            subtitle: subtitle,
            tint: Color.dreamCoral,
            status: remindersStatus,
            isTappable: remindersStatus == .needsSetup,
            action: enableReminders
        )
    }

    private var remindersSubtitle: LocalizedStringKey? {
        if remindersStatus == .needsSetup {
            switch permissions.notifications {
            case .denied: return "Notifications are off for Snoozly. Tap to open Settings."
            case .granted: return "Tap to turn reminders back on"
            case .notDetermined, .failed: return "Tap to allow notifications"
            }
        }
        guard let tonight = tonightNight, tonight.isEnabled else { return nil }
        return "\(tonight.bedtimeMinutes.clockText)"
    }

    private var changeScheduleRow: some View {
        Button {
            showSchedule()
        } label: {
            HStack(spacing: 12) {
                RowIcon(systemName: "slider.horizontal.3", tint: Color.lavendar)

                Text("Change in Schedule")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                RowChevron()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: Actions

    private func enableReminders() {
        Task {
            await permissions.allowNotifications(for: plan)
        }
    }

    private func allowAlarms() {
        Task {
            await permissions.allowAlarms(for: plan)
        }
    }

    private func chooseQuietApps() {
        Task {
            if await permissions.allowScreenTime() {
                showQuietPicker = true
            }
        }
    }

    // MARK: - Upcoming Nights

    private var upcomingNightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle("Upcoming Nights", showsPro: true)

                Text(proManager.isPro ? "Tap a night to see how it looks" : "Unlock Pro to look two weeks ahead")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.7))
            }
            .padding(.horizontal, gutter)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<14, id: \.self) { dayOffset in
                        upcomingNightCard(dayOffset: dayOffset)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, gutter, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    private func upcomingDate(for dayOffset: Int) -> Date {
        let base = Calendar.current.date(byAdding: .hour, value: -6, to: .now) ?? .now
        return Calendar.current.date(byAdding: .day, value: dayOffset, to: base) ?? base
    }

    private func upcomingSheet(for dayOffset: Int) -> some View {
        let targetDay = tonightWeekday.shifted(by: dayOffset)
        let night = plan?.sortedNights.first { $0.weekday == targetDay }

        return UpcomingNightSheet(
            night: night,
            plan: plan,
            date: upcomingDate(for: dayOffset),
            isTonight: dayOffset == 0,
            isSkipped: dayOffset == 0 && isTonightSkipped
        ) {
            upcomingSelection = nil
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                showSchedule(targetDay)
            }
        }
    }

    private func upcomingNightCard(dayOffset: Int) -> some View {
        let isToday = dayOffset == 0
        let targetDay = tonightWeekday.shifted(by: dayOffset)
        let night = plan?.sortedNights.first { $0.weekday == targetDay }
        let isOn = night?.isEnabled == true
        let bedtimeText = isOn ? (night?.bedtimeMinutes.clockText ?? "–") : "Off"
        let durationText = isOn ? (night?.sleepMinutes ?? 0).durationText : "No bedtime"
        let isUnlocked = isToday || proManager.isPro

        return Button {
            if isUnlocked {
                upcomingSelection = UpcomingSelection(dayOffset: dayOffset)
            } else {
                showProSheet = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(isToday ? "Tonight" : targetDay.shortName)
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.0)
                    .foregroundStyle(isToday ? Color.starlightGold : Color.lavendar.opacity(0.85))

                VStack(alignment: .leading, spacing: 3) {
                    Text(bedtimeText)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(isOn ? Color.white : Color.lavendar.opacity(0.45))

                    HStack(spacing: 4) {
                        Image(systemName: isOn ? "moon.zzz.fill" : "moon.zzz")
                            .font(.system(size: 10, weight: .semibold))

                        Text(durationText)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(Color.lavendar.opacity(0.75))
                }
            }
            .frame(width: 112, alignment: .leading)
            .padding(16)
            .blur(radius: isUnlocked ? 0 : 4)
            .overlay {
                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.starlightGold)
                        .shadow(color: Color.black.opacity(0.4), radius: 6)
                }
            }
            .nightCard(cornerRadius: 24, tint: isToday ? Color.dreamPurple : nil, blurs: false)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    TonightView()
        .modelContainer(preview.container)
}
