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
    case pro
    case checkIn

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
    @State private var proManager = ProManager.shared
    @State private var permissions = PermissionCenter.shared
    @State private var router = QuickActionRouter.shared
    @State private var selectedTab: Int = 0
    @State private var scheduleWeekday: Weekday = .today
    @State private var activeSheet: ContentSheet?
    @State private var hasHandledLaunch = false

    private var reminderKey: [Int] {
        (plans.first?.notificationSignature ?? []) + [scenePhase == .active ? 1 : 0]
    }

    private var quietKey: String {
        (plans.first?.quietSignature ?? "") + (scenePhase == .active ? "|active" : "|inactive")
    }

    private var isTonightSkipped: Bool {
        skipDateString == TonightSkip.nightKey
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
        .sheet(item: $activeSheet, onDismiss: runPendingQuickAction) { sheet in
            switch sheet {
            case .pro:
                ProSheetView()
            case .checkIn:
                CheckInSheetView()
            }
        }
        .onChange(of: router.pending) { _, newValue in
            if newValue != nil && activeSheet == nil && hasHandledLaunch {
                runPendingQuickAction()
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
        .task(id: skipDateString) {
            router.refreshShortcutItems(isSkipped: isTonightSkipped)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await permissions.refresh()
        }
        .task(id: reminderKey) {
            guard scenePhase == .active, let plan = plans.first else { return }
            await NotificationManager.shared.reschedule(for: plan)
        }
        .task(id: quietKey) {
            guard scenePhase == .active, let plan = plans.first else { return }
            ScreenTimeService.reschedule(for: plan)
        }
        .task(id: plans.first?.alarmSignature) {
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
            runPendingQuickAction()
        } else {
            activeSheet = .pro
        }
    }

    // MARK: - Review Prompt

    private func considerReviewPrompt() {
        guard let latest = checkIns.first,
              ReviewPrompter.shouldPrompt(checkInCount: checkIns.count, latestScore: latest.score) else { return }

        Task {
            try? await Task.sleep(for: .seconds(2))
            guard activeSheet == nil else { return }
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
            TonightSkip.toggle()
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
