//
//  WindDownView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI
import SwiftData
import FamilyControls

struct WindDownView: View {
    @Bindable var plan: SleepPlan
    var isActive: Bool

    @State private var appSelection = FamilyActivitySelection()
    @State private var showsPicker = false
    @State private var screenTimeFailed = false
    @State private var notificationsDenied = false

    @State private var appearTick = 0

    @Environment(\.onboardingWide) private var pageIsWide

    private let options = [15, 30, 45, 60]

    private var referenceNight: NightPlan? {
        plan.sortedNights.first { $0.isEnabled }
    }

    private var selectedCount: Int {
        appSelection.applicationTokens.count
            + appSelection.categoryTokens.count
            + appSelection.webDomainTokens.count
    }

    private var selectionSummary: LocalizedStringKey {
        selectedCount == 0 ? "Choose apps to quiet" : "\(selectedCount) selected"
    }

    var body: some View {
        OnboardingPageContainer(centersContent: true) {
            let isWide = pageIsWide
            let layout = isWide
                ? AnyLayout(HStackLayout(alignment: .center, spacing: 20))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))

            layout {
                VStack(alignment: .leading, spacing: 12) {
                    OnboardingHeadline(
                        title: "Let's slow things down.",
                        subtitle: "How long would you like to wind down before bed?"
                    )
                    .reveal(isActive, delay: 0.05)

                    WindDownOptionPicker(selection: $plan.windDownMinutes, options: options)
                        .reveal(isActive, delay: 0.15)

                    durationCard
                        .reveal(isActive, delay: 0.25, offset: 26)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 12) {
                    notificationsCard
                        .reveal(isActive, delay: 0.35, offset: 26)

                    screenTimeCard
                        .reveal(isActive, delay: 0.45, offset: 26)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .id(appearTick)
        .onChange(of: appSelection) { _, newValue in
            plan.blockedAppsData = try? JSONEncoder().encode(newValue)
            ScreenTimeService.saveSelection(newValue)
            ScreenTimeService.reschedule(for: plan, force: true)
        }
        .task {
            if let data = plan.blockedAppsData,
               let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
                appSelection = saved
                ScreenTimeService.saveSelection(saved)
            }
        }
        .onAppear { appearTick += 1 }
    }

    // MARK: - Duration

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(plan.windDownMinutes)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(
                                LinearGradient(colors: [Color.white, Color.lavendar],
                                               startPoint: .top,
                                               endPoint: .bottom)
                            )
                            .shadow(color: Color.dreamPurple.opacity(0.5), radius: 12)
                            .contentTransition(.numericText())

                        Text("min")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.lavendar)
                    }

                    Text(blurb(for: plan.windDownMinutes))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.lavendar.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                RowIcon(systemName: symbol(for: plan.windDownMinutes), size: 48, tint: Color.lavendar)
            }

            timeline
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard(cornerRadius: 28)
        .animation(.snappy, value: plan.windDownMinutes)
    }

    private var timeline: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .trailing) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(
                            LinearGradient(colors: [Color.dreamPurple.opacity(0.25), Color.lavendar],
                                           startPoint: .leading,
                                           endPoint: .trailing)
                        )
                        .frame(width: max(geo.size.width * CGFloat(plan.windDownMinutes) / 60, 16))
                        .shadow(color: Color.dreamPurple.opacity(0.6), radius: 8)
                }
            }
            .frame(height: 10)

            if let night = referenceNight {
                HStack(spacing: 8) {
                    Label {
                        Text("Starts \(windDownStart(for: night).clockText)")
                    } icon: {
                        Image(systemName: "sparkles")
                    }

                    Spacer(minLength: 8)

                    Label {
                        Text("Bedtime \(night.bedtimeMinutes.clockText)")
                    } icon: {
                        Image(systemName: "moon.fill")
                    }
                }
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Color.lavendar.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
    }

    private func windDownStart(for night: NightPlan) -> Int {
        (night.bedtimeMinutes - plan.windDownMinutes + 24 * 60) % (24 * 60)
    }

    private func symbol(for minutes: Int) -> String {
        switch minutes {
        case 15: "cup.and.saucer.fill"
        case 30: "book.fill"
        case 45: "leaf.fill"
        default: "moon.stars.fill"
        }
    }

    private func blurb(for minutes: Int) -> LocalizedStringKey {
        switch minutes {
        case 15: "A tiny pause before bed"
        case 30: "A little room to unwind"
        case 45: "Time for a calm routine"
        default: "A slower evening"
        }
    }

    // MARK: - Toggle cards

    private func toggleHeader(symbol: String,
                              title: LocalizedStringKey,
                              isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            RowIcon(systemName: symbol, size: 44, tint: Color.starlightGold)

            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            Toggle(isOn: isOn) {
                Text(title)
            }
            .labelsHidden()
            .tint(Color.dreamPurple)
        }
    }

    private func toggleDetail(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(Color.lavendar.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Notifications

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            toggleHeader(symbol: "bell.badge.fill",
                         title: "Gentle reminders",
                         isOn: notificationsBinding)

            toggleDetail("A soft nudge at wind-down and at bedtime.")

            if notificationsDenied {
                OnboardingHint(text: "Notifications are off for Snoozly. You can allow them in Settings.")
                    .transition(.opacity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard(cornerRadius: 28)
        .animation(.easeOut(duration: 0.2), value: notificationsDenied)
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { plan.notificationsEnabled },
            set: { setNotifications($0) }
        )
    }

    private func setNotifications(_ isOn: Bool) {
        notificationsDenied = false
        plan.notificationsEnabled = isOn
        guard isOn else { return }

        Task {
            let granted = await NotificationManager.shared.requestAuthorization()
            if !granted {
                plan.notificationsEnabled = false
                notificationsDenied = true
            }
        }
    }

    // MARK: - Screen Time

    private var screenTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            toggleHeader(symbol: "hourglass",
                         title: "Quiet your apps",
                         isOn: blockingBinding)

            toggleDetail("Blocks the apps you choose from wind-down until you wake up.")

            if plan.phoneHabit == .often && !plan.blocksAppsDuringWindDown {
                Label("Suggested, since your phone keeps you up", systemImage: "sparkles")
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.starlightGold)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if plan.blocksAppsDuringWindDown {
                Button {
                    openPicker()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apps.iphone")
                            .foregroundStyle(Color.lavendar)
                        Text(selectionSummary)
                            .foregroundStyle(.white)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.lavendar.opacity(0.6))
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 46)
                    .nightWell(cornerRadius: 16)
                }
                .buttonStyle(PressScaleButtonStyle())
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }

            if screenTimeFailed {
                OnboardingHint(text: "Screen Time access wasn't granted. You can try again anytime.")
                    .transition(.opacity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard(cornerRadius: 28)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: plan.blocksAppsDuringWindDown)
        .animation(.easeOut(duration: 0.2), value: screenTimeFailed)
        .familyActivityPicker(isPresented: $showsPicker, selection: $appSelection)
    }

    private var blockingBinding: Binding<Bool> {
        Binding(
            get: { plan.blocksAppsDuringWindDown },
            set: { setBlocking($0) }
        )
    }

    private func setBlocking(_ isOn: Bool) {
        screenTimeFailed = false
        plan.blocksAppsDuringWindDown = isOn

        guard isOn else {
            ScreenTimeService.reschedule(for: plan, force: true)
            return
        }

        Task {
            let wasAuthorized = ScreenTimeService.isAuthorized

            guard await ScreenTimeService.requestAuthorization() else {
                plan.blocksAppsDuringWindDown = false
                screenTimeFailed = true
                return
            }

            if !wasAuthorized {
                try? await Task.sleep(for: .milliseconds(300))
            }
            showsPicker = true
        }
    }

    private func openPicker() {
        Task {
            if await ScreenTimeService.requestAuthorization() {
                showsPicker = true
            } else {
                screenTimeFailed = true
            }
        }
    }
}

private struct WindDownOptionPicker: View {
    @Binding var selection: Int
    let options: [Int]

    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { minutes in
                let isSelected = selection == minutes

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selection = minutes
                    }
                } label: {
                    Text("\(minutes) min")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isSelected ? Color.midnightNavy : Color.white.opacity(0.9))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(NightGradient.lavender)
                                    .overlay {
                                        Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                                    }
                                    .shadow(color: Color.dreamPurple.opacity(0.5), radius: 10, y: 3)
                                    .matchedGeometryEffect(id: "windDownHighlight", in: highlight)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background {
            Capsule().fill(Color.black.opacity(0.24))
        }
        .overlay {
            Capsule().strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        }
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityLabel("Wind-down length")
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    ZStack {
        NightBackground()
        WindDownView(plan: preview.plan, isActive: true)
            .padding()
    }
    .modelContainer(preview.container)
}
