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
    @State private var showQuietPicker = false
    @State private var sheetWeekday: Weekday = .today
    @State private var selectedEvening: Date?
    @State private var permissions = PermissionCenter.shared
    @State private var appeared = false
    @ScaledMetric(relativeTo: .largeTitle) private var heroTimeSize: CGFloat = 48

    private let gutter: CGFloat = 20
    private let topAnchor = "tonight.top"

    private enum RowStatus {
        case on
        case off
        case needsSetup
    }

    // MARK: - Night Selection

    private var plan: SleepPlan? {
        plans.first
    }

    private var currentNight: NightRef {
        NightClock.current(plan: plan)
    }

    private var displayedNight: NightRef {
        guard let selectedEvening else { return currentNight }
        let day = Calendar.current.startOfDay(for: selectedEvening)
        return day > currentNight.evening ? NightRef(evening: day) : currentNight
    }

    private var isViewingCurrent: Bool {
        displayedNight == currentNight
    }

    private var displayedWeekday: Weekday {
        displayedNight.weekday
    }

    private var displayedPlan: NightPlan? {
        NightClock.night(on: displayedNight, in: plan)
    }

    private var isCurrentSkipped: Bool {
        skipDateString == currentNight.key
    }

    private var isDisplayedSkipped: Bool {
        isViewingCurrent && isCurrentSkipped
    }

    private func setSkipped(_ skipped: Bool) {
        skipDateString = skipped ? currentNight.key : ""
        Haptics.play(skipped ? .skip : .resume)
    }

    private func showSchedule(_ weekday: Weekday? = nil) {
        let target = weekday ?? displayedWeekday

        if let onShowSchedule {
            onShowSchedule(target)
        } else {
            sheetWeekday = target
            showScheduleSheet = true
        }
    }

    private func select(_ ref: NightRef, isUnlocked: Bool, proxy: ScrollViewProxy) {
        guard isUnlocked else {
            Haptics.play(.warning)
            showProSheet = true
            return
        }

        guard ref != displayedNight else {
            Haptics.play(.tap)
            return
        }

        Haptics.play(.select)

        withAnimation(.snappy) {
            selectedEvening = ref == currentNight ? nil : ref.evening
            proxy.scrollTo(topAnchor, anchor: .top)
        }
    }

    private func showTonight(proxy: ScrollViewProxy) {
        Haptics.play(.confirm)

        withAnimation(.snappy) {
            selectedEvening = nil
            proxy.scrollTo(topAnchor, anchor: .top)
        }
    }

    // MARK: - Text

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

    private var headerDateText: String {
        let date = isViewingCurrent ? Date.now : displayedNight.evening
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var headerTitle: String {
        isViewingCurrent ? greetingText : "\(displayedWeekday.fullName) Night"
    }

    private func durationLabel(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours)h \(remainder)min" : "\(remainder)min"
    }

    private func windDownChip(night: NightPlan?, isOn: Bool) -> InfoChip {
        guard let night, isOn, !isDisplayedSkipped else {
            return InfoChip(icon: "clock.fill", text: "No Wind Down", tint: Color.starlightGold)
        }

        let windDownMinutes = plan?.windDownMinutes ?? 30

        guard isViewingCurrent else {
            let start = (night.bedtimeMinutes - windDownMinutes + 24 * 60) % (24 * 60)
            return InfoChip(icon: "clock.fill", text: "Wind Down \(start.clockText)", tint: Color.starlightGold)
        }

        switch night.phase(evening: displayedNight.evening, windDownMinutes: windDownMinutes) {
        case .beforeWindDown(let minutes):
            return InfoChip(icon: "clock.fill", text: "Wind Down in \(durationLabel(minutes))", tint: Color.starlightGold)
        case .windDown(let minutes):
            return InfoChip(icon: "wind", text: "Bed in \(durationLabel(minutes))", tint: Color.moonlightBlue)
        case .asleep(let minutes):
            return InfoChip(icon: "moon.zzz.fill", text: "Wake in \(durationLabel(minutes))", tint: Color.lavendar)
        case .finished:
            return InfoChip(icon: "clock.fill", text: "No Wind Down", tint: Color.starlightGold)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            NightBackground(mood: .tonight)

            ScrollViewReader { proxy in
                ScrollView {
                    TimelineView(.everyMinute) { _ in
                        VStack(alignment: .leading, spacing: 24) {
                            headerSection(proxy: proxy)
                                .padding(.horizontal, gutter)
                                .reveal(appeared, delay: 0)
                                .id(topAnchor)

                            heroCard
                                .padding(.horizontal, gutter)
                                .reveal(appeared, delay: 0.06)
                                .id("hero.\(displayedNight.key)")
                                .transition(.opacity.combined(with: .scale(scale: 0.97)))

                            if isViewingCurrent {
                                holdToSkipButton
                                    .padding(.horizontal, gutter)
                                    .reveal(appeared, delay: 0.12)
                                    .transition(.opacity)
                            }

                            remindersAndAlarmsSection
                                .padding(.horizontal, gutter)
                                .reveal(appeared, delay: 0.18)

                            upcomingNightsSection(proxy: proxy)
                                .reveal(appeared, delay: 0.24)
                        }
                        .padding(.vertical, 16)
                    }
                }
                .scrollIndicators(.hidden)
                .contentMargins(.bottom, 24, for: .scrollContent)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
            }
        }
        .revealOnAppear($appeared)
        .fullScreenCover(isPresented: $showProSheet) {
            ProSheetView()
        }
        .sheet(isPresented: $showScheduleSheet) {
            ScheduleView(selectedWeekday: $sheetWeekday)
        }
        .quietAppsPicker(for: plan, isPresented: $showQuietPicker)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await permissions.refresh()
        }
    }

    // MARK: - Header

    private func headerSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headerDateText)
                .font(.system(.footnote, design: .rounded, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(Color.starlightGold)

            Text(headerTitle)
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if !isViewingCurrent {
                Button {
                    showTonight(proxy: proxy)
                } label: {
                    Label("Show Tonight", systemImage: "moon.stars.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Color.midnightNavy)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(NightGradient.gold))
                        .shadow(color: Color.starlightGold.opacity(0.4), radius: 12, y: 4)
                }
                .buttonStyle(PressScaleButtonStyle())
                .padding(.top, 6)
                .accessibilityHint("Goes back to tonight's schedule")
                .transition(.scale(scale: 0.85, anchor: .leading).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        let night = displayedPlan
        let isOn = night?.isEnabled == true

        return ZStack {
            heroContent(night: night, isOn: isOn)
                .opacity(isDisplayedSkipped ? 0.4 : 1.0)
                .grayscale(isDisplayedSkipped ? 0.8 : 0.0)

            if isDisplayedSkipped {
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
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isDisplayedSkipped)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 32, style: .continuous))
        .contextMenu {
            if isViewingCurrent {
                Button {
                    withAnimation(.snappy) {
                        setSkipped(!isCurrentSkipped)
                    }
                } label: {
                    Label(isCurrentSkipped ? "Resume Tonight" : "Skip Tonight", systemImage: isCurrentSkipped ? "arrow.counterclockwise" : "moon.zzz.fill")
                }
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
                Text(isViewingCurrent ? "No bedtime scheduled for tonight." : "No bedtime scheduled for this night.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.75))
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    windDownChip(night: night, isOn: isOn)

                    alarmChip(night: night, isOn: isOn)

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    windDownChip(night: night, isOn: isOn)

                    alarmChip(night: night, isOn: isOn)
                }
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
        .accessibilityLabel(heroAccessibilityLabel(night: night, isOn: isOn))
    }

    private func heroAccessibilityLabel(night: NightPlan?, isOn: Bool) -> String {
        let when = isViewingCurrent ? "Tonight" : "\(displayedWeekday.fullName) night"

        guard let night, isOn else { return "\(when). No bedtime scheduled." }
        if isDisplayedSkipped { return "\(when) is skipped. Alarm, reminders and Quiet Apps are off." }

        let alarm = night.alarmEnabled ? "Alarm at \(night.wakeMinutes.clockText)." : "No alarm."
        return "\(when). Bedtime \(night.bedtimeMinutes.clockText). Wake-up \(night.wakeMinutes.clockText). \(night.sleepMinutes.durationText) of sleep. \(alarm)"
    }

    @ViewBuilder
    private func alarmChip(night: NightPlan?, isOn: Bool) -> some View {
        if let night, isOn, night.alarmEnabled, !isDisplayedSkipped {
            if permissions.alarms == .granted {
                InfoChip(icon: "alarm.fill", text: "Alarm \(night.wakeMinutes.clockText)", tint: Color.lavendar)
            } else {
                InfoChip(icon: "exclamationmark.circle.fill", text: "Alarm needs access", tint: Color.dreamCoral)
            }
        } else {
            InfoChip(icon: "alarm", text: "No Alarm", tint: Color.lavendar.opacity(0.6))
        }
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
            title: isCurrentSkipped ? "Hold to Resume Tonight" : "Hold to Skip Tonight",
            systemImage: isCurrentSkipped ? "arrow.counterclockwise" : "moon.zzz.fill",
            isHighlighted: isCurrentSkipped,
            playsCompletionHaptic: false
        ) {
            withAnimation(.snappy) {
                setSkipped(!isCurrentSkipped)
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
        .id("reminders.\(displayedNight.key)")
        .transition(.opacity)
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
        guard let night = displayedPlan, night.isEnabled, night.quietAppsEnabled, !isDisplayedSkipped else { return .off }
        return permissions.quietAppsReady(for: plan) ? .on : .needsSetup
    }

    private var alarmStatus: RowStatus {
        guard let night = displayedPlan, night.isEnabled, night.alarmEnabled, !isDisplayedSkipped else { return .off }
        return permissions.alarms == .granted ? .on : .needsSetup
    }

    private var remindersStatus: RowStatus {
        guard let night = displayedPlan, night.isEnabled, night.remindersEnabled, !isDisplayedSkipped else { return .off }
        return permissions.remindersActive(for: plan) ? .on : .needsSetup
    }

    // MARK: Rows

    private var quietAppsRow: some View {
        statusRow(
            icon: "hourglass",
            title: "Quiet Apps",
            subtitle: quietAppsSubtitle,
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
        guard let night = displayedPlan, night.isEnabled, night.quietAppsEnabled, !isDisplayedSkipped, let plan else { return nil }
        let startMinutes = (night.bedtimeMinutes - plan.windDownMinutes + 24 * 60) % (24 * 60)
        return "\(startMinutes.clockText) until wake-up"
    }

    private var alarmRow: some View {
        statusRow(
            icon: "alarm.fill",
            title: "Wake-up Alarm",
            subtitle: alarmSubtitle,
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
        guard let night = displayedPlan, night.isEnabled, night.alarmEnabled, !isDisplayedSkipped else { return nil }

        let minutes = night.wakeMinutes.clockText
        guard let plan, plan.effectiveSnoozeMinutes(for: night) > 0 else {
            return "\(minutes) · no snooze"
        }
        return "\(minutes) · snooze \(plan.effectiveSnoozeMinutes(for: night)) min"
    }

    private var bedtimeRemindersRow: some View {
        statusRow(
            icon: "bell.badge.fill",
            title: "Bedtime Reminders",
            subtitle: remindersSubtitle,
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
        guard let night = displayedPlan, night.isEnabled, night.remindersEnabled, !isDisplayedSkipped else { return nil }
        return "\(night.bedtimeMinutes.clockText)"
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

    private func upcomingNightsSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle("Upcoming Nights", showsPro: true)

                Text(proManager.isPro ? "Tap a night to see it here" : "Unlock Pro to look two weeks ahead")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.7))
            }
            .padding(.horizontal, gutter)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<14, id: \.self) { dayOffset in
                        upcomingNightCard(dayOffset: dayOffset, proxy: proxy)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 10)
            }
            .contentMargins(.horizontal, gutter, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    private func upcomingNightCard(dayOffset: Int, proxy: ScrollViewProxy) -> some View {
        let ref = currentNight.shifted(byDays: dayOffset)
        let isToday = dayOffset == 0
        let night = NightClock.night(on: ref, in: plan)
        let isOn = night?.isEnabled == true
        let isSelected = ref == displayedNight
        let bedtimeText = isOn ? (night?.bedtimeMinutes.clockText ?? "–") : "Off"
        let durationText = isOn ? (night?.sleepMinutes ?? 0).durationText : "No bedtime"
        let isUnlocked = isToday || proManager.isPro
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        return Button {
            select(ref, isUnlocked: isUnlocked, proxy: proxy)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    Text(isToday ? "Tonight" : ref.weekday.shortName)
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .textCase(.uppercase)
                        .tracking(1.0)
                        .foregroundStyle(isSelected || isToday ? Color.starlightGold : Color.lavendar.opacity(0.85))

                    Spacer(minLength: 0)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.starlightGold)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

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
            .nightCard(cornerRadius: 24,
                       tint: isSelected ? Color.starlightGold : (isToday ? Color.dreamPurple : nil),
                       blurs: false)
            .overlay {
                if isSelected {
                    shape.strokeBorder(Color.starlightGold, lineWidth: 2)
                }
            }
            .shadow(color: Color.starlightGold.opacity(isSelected ? 0.4 : 0), radius: 16, y: 6)
            .scaleEffect(isSelected ? 1.05 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(upcomingAccessibilityLabel(ref: ref, isToday: isToday, isOn: isOn, night: night, isUnlocked: isUnlocked))
        .accessibilityHint(isUnlocked ? "Shows this night on this page" : "Opens Snoozly Pro")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func upcomingAccessibilityLabel(ref: NightRef,
                                            isToday: Bool,
                                            isOn: Bool,
                                            night: NightPlan?,
                                            isUnlocked: Bool) -> String {
        let name = isToday ? "Tonight" : "\(ref.weekday.fullName) night"

        guard isUnlocked else { return "\(name). Locked, requires Snoozly Pro." }
        guard isOn, let night else { return "\(name). No bedtime." }
        return "\(name). Bedtime \(night.bedtimeMinutes.clockText), \(night.sleepMinutes.durationText) of sleep."
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    TonightView()
        .modelContainer(preview.container)
}
