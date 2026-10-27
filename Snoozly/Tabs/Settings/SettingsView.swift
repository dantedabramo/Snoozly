//
//  SettingsView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-12.
//

import SwiftUI
import SwiftData
import StoreKit

// MARK: - SettingsView

struct SettingsView: View {
    @Query private var plans: [SleepPlan]
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKey.profileName) private var profileName = ""
    @AppStorage(AppStorageKey.profileIcon) private var profileIcon = "moon.stars.fill"
    @AppStorage(AppStorageKey.sleepGoalMinutes) private var sleepGoalMinutes = 480

    @State private var proManager = ProManager.shared
    @State private var showProfileSheet = false
    @State private var showProSheet = false
    @State private var showQuietPicker = false
    @State private var showManageSubscriptions = false
    @State private var showOfferCodeRedemption = false
    @State private var showRefundRequest = false
    @State private var reminderAccess: NotificationManager.Access = .notDetermined
    @State private var alarmPermission = WakeAlarmService.permission
    @State private var screenTimeAllowed = ScreenTimeService.isAuthorized
    @State private var appeared = false

    private var plan: SleepPlan? {
        plans.first
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private let windDownOptions = [15, 30, 45, 60]
    private let sleepGoalOptions = [360, 420, 480, 540, 600]
    private let snoozeOptions = SleepPlan.snoozeChoices

    var body: some View {
        ZStack {
            NightBackground(mood: .settings)

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                        .reveal(appeared, delay: 0)

                    VStack(spacing: 14) {
                        profileCard
                        proStatusBanner
                    }
                    .reveal(appeared, delay: 0.06)

                    sleepSection
                        .reveal(appeared, delay: 0.12)

                    bedtimeRoutineSection
                        .reveal(appeared, delay: 0.18)

                    subscriptionSection
                        .reveal(appeared, delay: 0.24)

                    accessSection
                        .reveal(appeared, delay: 0.30)

                    informationSection
                        .reveal(appeared, delay: 0.36)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, 24, for: .scrollContent)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
        }
        .revealOnAppear($appeared)
        .sheet(isPresented: $showProfileSheet) {
            SetupProfileSheetView()
        }
        .sheet(isPresented: $showProSheet) {
            ProSheetView()
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .offerCodeRedemption(isPresented: $showOfferCodeRedemption) { result in
            Task {
                if case .failure = result {
                    proManager.errorMessage = "That code couldn't be redeemed. Check it and try again."
                }
                await proManager.refresh()
            }
        }
        .refundRequestSheet(for: proManager.activeTransactionID ?? 0, isPresented: $showRefundRequest)
        .quietAppsPicker(for: plan, isPresented: $showQuietPicker)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await refreshPermissions()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ScreenHeader("Settings", subtitle: "Make Snoozly feel like yours.")
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        Button {
            showProfileSheet = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [Color.dreamPurple.opacity(0.7), Color.dreamPurple.opacity(0.18)],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                        .frame(width: 64, height: 64)
                        .overlay {
                            Circle().strokeBorder(
                                LinearGradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0.08)],
                                               startPoint: .top,
                                               endPoint: .bottom),
                                lineWidth: 1.5
                            )
                        }
                        .shadow(color: Color.dreamPurple.opacity(0.55), radius: 14)

                    Image(systemName: profileIcon.isEmpty ? "moon.stars.fill" : profileIcon)
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(Color.starlightGold)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(profileName.isEmpty ? "Set up Profile" : profileName)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("View or modify Profile")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.lavendar.opacity(0.75))
                }

                Spacer()

                RowChevron()
            }
            .padding(18)
            .nightCard(cornerRadius: 28, tint: Color.dreamPurple)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: - Pro Banner

    private var proStatusBanner: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

        return Button {
            showProSheet = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.midnightNavy)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(NightGradient.gold))
                    .shadow(color: Color.starlightGold.opacity(0.5), radius: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(proManager.isPro ? "Snoozly Pro Active" : "Unlock Snoozly Pro")
                        .font(.system(.callout, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)

                    Text(proManager.isPro ? "Every Pro feature is unlocked" : "Longer trends, upcoming nights & more")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.lavendar.opacity(0.85))
                }

                Spacer()

                RowChevron()
            }
            .padding(16)
            .background {
                shape
                    .fill(
                        LinearGradient(colors: [Color.starlightGold.opacity(0.22), Color.dreamPurple.opacity(0.22)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .overlay {
                        shape.strokeBorder(
                            LinearGradient(colors: [Color.starlightGold.opacity(0.75), Color.starlightGold.opacity(0.15)],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                    }
            }
            .shadow(color: Color.starlightGold.opacity(0.18), radius: 18, y: 8)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: - Sleep

    private var sleepSection: some View {
        SettingsSection("SLEEP", footer: "Snooze length applies to every alarm. Turn snooze on or off for each morning in Schedule.") {
            SettingsRow(icon: "moon.fill", title: "Sleep Goal", tint: Color.lavendar) {
                menuPicker("Sleep Goal", selection: $sleepGoalMinutes, options: sleepGoalOptions) { "\($0 / 60) hrs" }
            }

            RowDivider()

            SettingsRow(icon: "clock.fill", title: "Wind-down Length", tint: Color.moonlightBlue) {
                if let plan {
                    menuPicker("Wind-down Length", selection: Bindable(plan).windDownMinutes, options: windDownOptions) { "\($0) min" }
                }
            }

            RowDivider()

            SettingsRow(icon: "zzz", title: "Snooze Length", tint: Color.starlightGold) {
                if let plan {
                    menuPicker("Snooze Length", selection: Bindable(plan).snoozeMinutes, options: snoozeOptions) {
                        $0 == 0 ? "Off" : "\($0) min"
                    }
                }
            }
        }
    }

    private func menuPicker<Value: Hashable>(
        _ title: LocalizedStringKey,
        selection: Binding<Value>,
        options: [Value],
        label: @escaping (Value) -> String
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(options, id: \.self) { option in
                Text(label(option)).tag(option)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(Color.lavendar)
        .fontWeight(.semibold)
        .sensoryFeedback(.selection, trigger: selection.wrappedValue)
    }

    // MARK: - Bedtime Routine

    private var remindersAreOn: Bool {
        plan?.notificationsEnabled == true && reminderAccess == .allowed
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { remindersAreOn },
            set: { newValue in
                guard let plan else { return }
                if newValue {
                    Task {
                        await NotificationManager.shared.turnOnReminders(for: plan)
                        await refreshPermissions()
                    }
                } else {
                    plan.notificationsEnabled = false
                }
            }
        )
    }

    private var reminderSubtitle: LocalizedStringKey {
        if reminderAccess == .denied {
            return "Notifications are off for Snoozly. Turn on to open Settings."
        }
        return "A soft nudge at wind-down and at bedtime."
    }

    private var quietAppsSubtitle: LocalizedStringKey {
        guard let plan else { return "Choose apps to quiet" }
        let count = ScreenTimeService.selectionCount(for: plan)
        if !screenTimeAllowed { return "Needs Screen Time access" }
        return count == 0 ? "Choose apps to quiet" : "\(count) selected, quiet from wind-down until you wake"
    }

    private var bedtimeRoutineSection: some View {
        SettingsSection("BEDTIME ROUTINE") {
            SettingsRow(icon: "bell.badge.fill", title: "Bedtime Reminders", subtitle: reminderSubtitle, tint: Color.dreamCoral) {
                Toggle("Bedtime Reminders", isOn: reminderBinding)
                    .labelsHidden()
                    .tint(Color.dreamPurple)
            }

            RowDivider()

            Button {
                chooseQuietApps()
            } label: {
                SettingsRow(icon: "hourglass", title: "Quiet Apps", subtitle: quietAppsSubtitle, tint: Color.moonlightBlue) {
                    HStack(spacing: 8) {
                        if let plan {
                            StatusCapsule(kind: ScreenTimeService.isReady(for: plan) ? .on : .setUp)
                        }
                        RowChevron()
                    }
                }
            }
            .buttonStyle(PressScaleButtonStyle())
        }
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        SettingsSection("SUBSCRIPTION") {
            if proManager.isPro {
                Button {
                    showManageSubscriptions = true
                } label: {
                    SettingsRow(icon: "creditcard.fill", title: "Manage Subscription", tint: Color.lavendar) { RowChevron() }
                }
                .buttonStyle(PressScaleButtonStyle())

                RowDivider()

                if proManager.activeTransactionID != nil {
                    Button {
                        showRefundRequest = true
                    } label: {
                        SettingsRow(icon: "arrow.uturn.backward.circle.fill", title: "Request a Refund", tint: Color.dreamCoral) { RowChevron() }
                    }
                    .buttonStyle(PressScaleButtonStyle())

                    RowDivider()
                }
            }

            Button {
                showOfferCodeRedemption = true
            } label: {
                SettingsRow(icon: "gift.fill", title: "Redeem Offer Code", tint: Color.dreamCoral) { RowChevron() }
            }
            .buttonStyle(PressScaleButtonStyle())

            RowDivider()

            Button {
                Task {
                    await proManager.restorePurchases()
                }
            } label: {
                SettingsRow(icon: "arrow.clockwise", title: "Restore Purchases", tint: Color.moonlightBlue) {
                    if proManager.isRestoring {
                        SwiftUI.ProgressView()
                            .controlSize(.small)
                            .tint(Color.lavendar)
                    }
                }
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(proManager.isRestoring)

            if let message = proManager.errorMessage {
                Text(message)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.starlightGold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Access

    private var accessSection: some View {
        SettingsSection("ACCESS") {
            SettingsRow(icon: "bell.fill", title: "Notifications", tint: Color.dreamCoral) {
                AccessPill(isAllowed: reminderAccess == .allowed) {
                    requestNotificationAccess()
                }
            }

            RowDivider()

            SettingsRow(icon: "alarm.fill", title: "Alarms", tint: Color.starlightGold) {
                AccessPill(isAllowed: alarmPermission == .authorized) {
                    requestAlarmAccess()
                }
            }

            RowDivider()

            SettingsRow(icon: "hourglass", title: "Screen Time", tint: Color.moonlightBlue) {
                AccessPill(isAllowed: screenTimeAllowed) {
                    requestScreenTimeAccess()
                }
            }
        }
    }

    // MARK: - Information

    private var informationSection: some View {
        SettingsSection("INFORMATION") {
            Link(destination: URL(string: "https://apps.apple.com/app/id6822070712?action=write-review")!) {
                SettingsRow(icon: "star.bubble.fill", title: "Rate Snoozly", tint: Color.starlightGold) {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.lavendar.opacity(0.5))
                }
            }

            RowDivider()

            SettingsRow(icon: "info.circle.fill", title: "Version", tint: Color.lavendar) {
                Text(versionText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.7))
            }
        }
    }

    // MARK: - Actions

    private func refreshPermissions() async {
        reminderAccess = await NotificationManager.shared.access()
        alarmPermission = WakeAlarmService.permission
        screenTimeAllowed = ScreenTimeService.isAuthorized
    }

    private func chooseQuietApps() {
        Task {
            screenTimeAllowed = await ScreenTimeService.prepareForPicker()
            if screenTimeAllowed {
                showQuietPicker = true
            }
        }
    }

    private func requestNotificationAccess() {
        guard let plan else { return }
        Task {
            await NotificationManager.shared.turnOnReminders(for: plan)
            await refreshPermissions()
        }
    }

    private func requestAlarmAccess() {
        Task {
            if alarmPermission == .notDetermined {
                alarmPermission = await WakeAlarmService.requestPermission()
                if let plan, alarmPermission == .authorized {
                    await WakeAlarmService.reschedule(for: plan, force: true)
                }
            } else {
                openSystemSettings()
            }
        }
    }

    private func requestScreenTimeAccess() {
        Task {
            screenTimeAllowed = await ScreenTimeService.requestAuthorization()
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    SettingsView()
        .modelContainer(preview.container)
}
