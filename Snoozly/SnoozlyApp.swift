//
//  SnoozlyApp.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-12.
//

import SwiftUI
import SwiftData

// MARK: - App Entry Point

@main
struct SnoozlyApp: App {
    @UIApplicationDelegateAdaptor(SnoozlyAppDelegate.self) private var appDelegate
    @State private var showSplash = true
    @AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    init() {
        NotificationManager.shared.registerAsDelegate()
        ReviewPrompter.registerLaunch()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasCompletedOnboarding {
                    ContentView(isReady: !showSplash)
                        .transition(.opacity)
                } else {
                    OnboardingView(isReady: !showSplash)
                        .transition(.opacity)
                }

                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.9)) {
                            showSplash = false
                        }
                    }
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 1.04))))
                    .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.6), value: hasCompletedOnboarding)
            .background(Color.midnightNavy.ignoresSafeArea())
        }
        .modelContainer(for: [SleepPlan.self, NightPlan.self, SleepCheckIn.self])
    }
}
