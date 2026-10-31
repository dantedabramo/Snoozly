//
//  OnboardingView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    var isReady: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [SleepPlan]
    @AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            if let plan = plans.first {
                OnboardingFlow(plan: plan, isReady: isReady) {
                    hasCompletedOnboarding = true
                }
            } else {
                Color.midnightNavy.ignoresSafeArea()
            }
        }
        .onAppear(perform: createPlanIfNeeded)
    }

    private func createPlanIfNeeded() {
        let existing = (try? modelContext.fetchCount(FetchDescriptor<SleepPlan>())) ?? 0
        if existing == 0 {
            SleepPlan.makeDefault(in: modelContext)
        }
    }
}

// MARK: - Flow

private struct OnboardingFlow: View {
    var plan: SleepPlan
    var isReady: Bool
    var onFinish: () -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var hasAppeared = false
    @State private var isFinishing = false

    @State private var includesAlarm = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var steps: [OnboardingStep] {
        OnboardingStep.allCases.filter { $0 != .alarm || includesAlarm }
    }

    private func refreshSteps() {
        includesAlarm = plan.hasAlarms
    }
    private var stepIndex: Int { steps.firstIndex(of: step) ?? 0 }

    private var pageAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.6, dampingFraction: 0.86)
    }

    var body: some View {
        GeometryReader { geo in
            let hasRoomToMirror = geo.size.width >= 700
            let startMargin = hasRoomToMirror ? geo.safeAreaInsets.trailing : 0
            let endMargin = hasRoomToMirror ? geo.safeAreaInsets.leading : 0

            VStack(spacing: 0) {
                header
                pages
                footer
            }
            .padding(.leading, startMargin)
            .padding(.trailing, endMargin)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            NightBackground(mood: .calm)
        }
        .haptic(.sheetOpen, trigger: step)
        .onAppear(perform: refreshSteps)
        .task(id: isReady) {
            guard isReady else { return }
            try? await Task.sleep(for: .milliseconds(200))
            hasAppeared = true
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            OnboardingPageIndicator(count: steps.count, current: stepIndex)

            HStack {
                OnboardingBackButton(action: goBack)
                    .opacity(step.showsBackButton ? 1 : 0)
                    .allowsHitTesting(step.showsBackButton)
                    .accessibilityHidden(!step.showsBackButton)
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .frame(height: 60)
        .animation(pageAnimation, value: step)
        .animation(pageAnimation, value: steps.count)
    }

    // MARK: - Pages

    private var pages: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(OnboardingStep.allCases) { item in
                    let isCurrent = item == step

                    page(for: item, isActive: hasAppeared && isCurrent)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .offset(x: CGFloat(item.rawValue - step.rawValue) * geo.size.width * 0.4)
                        .opacity(isCurrent ? 1 : 0)
                        .allowsHitTesting(isCurrent)
                        .accessibilityHidden(!isCurrent)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .environment(\.onboardingWide, geo.size.width >= 700)
            .animation(pageAnimation, value: step)
        }
    }

    @ViewBuilder
    private func page(for step: OnboardingStep, isActive: Bool) -> some View {
        switch step {
        case .welcome:
            WelcomeView(isActive: isActive)
        case .purpose:
            PurposeView(plan: plan, isActive: isActive)
        case .howItHelps:
            HowItHelpsView(isActive: isActive)
        case .bedtime:
            BedtimeView(plan: plan, isActive: isActive)
        case .wakeUp:
            WakeUpView(plan: plan, isActive: isActive)
        case .alarm:
            AlarmSetupView(plan: plan, isActive: isActive)
        case .windDown:
            WindDownView(plan: plan, isActive: isActive)
        case .review:
            ReviewView(plan: plan, isActive: isActive, goTo: goTo)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        OnboardingForwardButton(
            title: step.forwardTitle,
            systemImage: step.forwardIcon,
            isEnabled: canAdvance,
            isBusy: isFinishing,
            action: advance
        )
        .frame(maxWidth: 520)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Navigation

    private var canAdvance: Bool {
        switch step {
        case .bedtime, .wakeUp: plan.nights.contains { $0.isEnabled }
        default: true
        }
    }

    private func advance() {
        refreshSteps()

        if stepIndex + 1 < steps.count {
            let next = steps[stepIndex + 1]
            withAnimation(pageAnimation) { step = next }
        } else {
            finish()
        }
    }

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true

        Task {
            await NotificationManager.shared.reschedule(for: plan)
            ScreenTimeService.reschedule(for: plan, force: true)
            await WakeAlarmService.reschedule(for: plan, force: true)
            onFinish()
        }
    }

    private func goTo(_ target: OnboardingStep) {
        refreshSteps()
        withAnimation(pageAnimation) { step = target }
    }

    private func goBack() {
        refreshSteps()
        guard stepIndex > 0 else { return }
        let previous = steps[stepIndex - 1]
        withAnimation(pageAnimation) { step = previous }
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    OnboardingView()
        .modelContainer(preview.container)
}
