//
//  ContentView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-12.
//

import SwiftUI
import SwiftData
import StoreKit

// MARK: - ContentSheet

private enum ContentSheet: String, Identifiable {
    case checkIn

    var id: String { rawValue }
}

// MARK: - ContentCover

private enum ContentCover: String, Identifiable {
    case pro

    var id: String { rawValue }
}

// MARK: - ContentView

struct ContentView: View {
    var isReady: Bool = true

    @Query private var plans: [SleepPlan]
    @Query(sort: \SleepCheckIn.date, order: .reverse) private var checkIns: [SleepCheckIn]
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKey.skipDateString) private var skipDateString = ""
    @AppStorage(AppStorageKey.lastCheckInPromptDay) private var lastCheckInPromptDay = ""
    @State private var proManager = ProManager.shared
    @State private var permissions = PermissionCenter.shared
    @State private var router = QuickActionRouter.shared
    @State private var selectedTab: Int = 0
    @State private var scheduleWeekday: Weekday = .today
    @State private var activeSheet: ContentSheet?
    @State private var activeCover: ContentCover?
    @State private var hasHandledLaunch = false

    private var skipTag: String {
        isTonightSkipped ? skipDateString : "-"
    }

    private var reminderKey: String {
        "\((plans.first?.notificationSignature ?? []) + [scenePhase == .active ? 1 : 0])|\(skipTag)"
    }

    private var quietKey: String {
        (plans.first?.quietSignature ?? "") + (scenePhase == .active ? "|active" : "|inactive") + "|\(permissions.alarms)|\(skipTag)"
    }

    private var isTonightSkipped: Bool {
        skipDateString == TonightSkip.nightKey(plan: plans.first)
    }

    private var hasCheckInToday: Bool {
        checkIns.contains { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Tonight", systemImage: "moon.stars.fill", value: 0) {
                TonightView(onShowSchedule: { weekday in
                    if let weekday {
                        scheduleWeekday = weekday
                    }
                    selectedTab = 1
                })
            }

            Tab("Schedule", systemImage: "calendar", value: 1) {
                ScheduleView(selectedWeekday: $scheduleWeekday)
            }

            Tab("Progress", systemImage: "chart.bar.fill", value: 2) {
                ProgressView()
            }

            Tab("Settings", systemImage: "gearshape", value: 3) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .task {
            await ProManager.shared.updatePurchasedStatus()
        }
        .haptic(.tab, trigger: selectedTab)
        .fullScreenCover(item: $activeCover, onDismiss: continueAfterPro) { cover in
            switch cover {
            case .pro:
                ProSheetView()
            }
        }
        .sheet(item: $activeSheet, onDismiss: runPendingQuickAction) { sheet in
            switch sheet {
            case .checkIn:
                CheckInSheetView()
            }
        }
        .onChange(of: router.pending) { _, newValue in
            if newValue != nil && activeSheet == nil && activeCover == nil && hasHandledLaunch {
                runPendingQuickAction()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                presentCheckInIfDue()
            }
        }
        .onChange(of: checkIns.count) { oldValue, newValue in
            if newValue > oldValue {
                considerReviewPrompt()
            }
        }
        .task(id: isReady) {
            await handleLaunch()
        }
        .task(id: "\(skipDateString)|\(scenePhase == .active)") {
            guard scenePhase == .active else { return }
            router.refreshShortcutItems(isSkipped: isTonightSkipped)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await permissions.refresh()
            if let plan = plans.first {
                ScreenTimeService.settleWakeHold(for: plan)
            }
        }
        .task(id: reminderKey) {
            guard scenePhase == .active, let plan = plans.first else { return }
            await NotificationManager.shared.reschedule(for: plan)
        }
        .task(id: quietKey) {
            guard scenePhase == .active, let plan = plans.first else { return }
            ScreenTimeService.reschedule(for: plan)
        }
        .task(id: "\(plans.first?.alarmSignature ?? "")|\(skipTag)|\(scenePhase == .active)") {
            guard let plan = plans.first else { return }
            plan.normalizeSnooze()
            await WakeAlarmService.reschedule(for: plan)
        }
        .task(id: permissions.alarms) {
            guard permissions.alarms == .granted, let plan = plans.first else { return }
            await WakeAlarmService.reschedule(for: plan)
        }
        .task(id: permissions.screenTime) {
            guard permissions.screenTime == .granted, let plan = plans.first else { return }
            ScreenTimeService.reschedule(for: plan)
        }
    }

    // MARK: - Launch

    private func handleLaunch() async {
        guard isReady, !hasHandledLaunch else { return }
        hasHandledLaunch = true

        await proManager.waitUntilResolved()
        try? await Task.sleep(for: .milliseconds(450))

        if proManager.isPro {
            continueAfterPro()
        } else {
            activeCover = .pro
        }
    }

    private func continueAfterPro() {
        if router.pending != nil {
            runPendingQuickAction()
        } else {
            presentCheckInIfDue()
        }
    }

    // MARK: - Morning Check-In

    private func presentCheckInIfDue() {
        guard hasHandledLaunch, activeCover == nil, activeSheet == nil, router.pending == nil else { return }

        let isDue = CheckInSchedule.isDue(
            plan: plans.first,
            hasCheckInToday: hasCheckInToday,
            lastPromptDay: lastCheckInPromptDay
        )
        guard isDue else { return }

        Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard activeCover == nil, activeSheet == nil else { return }
            lastCheckInPromptDay = CheckInSchedule.dayKey()
            activeSheet = .checkIn
        }
    }

    // MARK: - Review Prompt

    private func considerReviewPrompt() {
        guard let latest = checkIns.first,
              ReviewPrompter.shouldPrompt(checkInCount: checkIns.count, latestScore: latest.score) else { return }

        Task {
            try? await Task.sleep(for: .seconds(2))
            guard activeSheet == nil, activeCover == nil else { return }
            ReviewPrompter.markPrompted()
            requestReview()
        }
    }

    // MARK: - Quick Actions

    private func runPendingQuickAction() {
        guard let action = router.consume() else { return }

        switch action {
        case .checkIn:
            selectedTab = 2
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                activeSheet = .checkIn
            }
        case .skipTonight:
            selectedTab = 0
            let wasSkipped = isTonightSkipped
            TonightSkip.toggle(plan: plans.first)
            Haptics.play(wasSkipped ? .resume : .skip)
        case .schedule:
            scheduleWeekday = .today
            selectedTab = 1
        }
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    ContentView()
        .modelContainer(preview.container)
}
