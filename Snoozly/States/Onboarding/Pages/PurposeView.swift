//
//  PurposeView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import SwiftUI
import SwiftData

struct PurposeView: View {
    @Bindable var plan: SleepPlan
    var isActive: Bool

    @State private var taps = 0
    @Environment(\.onboardingWide) private var pageIsWide

    var body: some View {
        OnboardingPageContainer(centersContent: true) {
            let isWide = pageIsWide
            let layout = isWide
                ? AnyLayout(HStackLayout(alignment: .center, spacing: 28))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))

            layout {
                VStack(alignment: .leading, spacing: 20) {
                    OnboardingHeadline(
                        eyebrow: "Why Snoozly",
                        title: "Your phone is great at keeping you up.",
                        subtitle: "One more video, one more scroll. Snoozly helps you put the day down on time."
                    )
                    .reveal(isActive, delay: 0.05)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Does your phone keep you up at night?")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 8) {
                        ForEach(PhoneHabit.allCases) { habit in
                            option(habit)
                        }
                    }

                    if let habit = plan.phoneHabit {
                        Text(habit.response)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Color.lavendar.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .id(habit)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(16)
                .frame(maxWidth: 560, alignment: .leading)
                .nightCard(cornerRadius: 28)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: plan.phoneHabitRaw)
                .sensoryFeedback(.selection, trigger: taps)
                .reveal(isActive, delay: 0.2, offset: 26)
            }
        }
    }

    private func option(_ habit: PhoneHabit) -> some View {
        let isSelected = plan.phoneHabit == habit
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return Button {
            taps += 1
            plan.phoneHabit = habit
        } label: {
            HStack(spacing: 12) {
                Image(systemName: habit.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.midnightNavy : Color.lavendar)
                    .frame(width: 28)

                Text(habit.title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.midnightNavy : Color.white)

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.midnightNavy)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background {
                if isSelected {
                    shape
                        .fill(NightGradient.lavender)
                        .overlay {
                            shape.strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                        }
                        .shadow(color: Color.dreamPurple.opacity(0.45), radius: 8, y: 3)
                } else {
                    shape
                        .fill(Color.white.opacity(0.07))
                        .overlay {
                            shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    ZStack {
        NightBackground()
        PurposeView(plan: preview.plan, isActive: true)
            .padding()
    }
    .modelContainer(preview.container)
}
