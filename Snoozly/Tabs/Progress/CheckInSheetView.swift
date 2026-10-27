//
//  CheckInSheetView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-23.
//

import SwiftUI
import SwiftData

// MARK: - CheckInSheetView

struct CheckInSheetView: View {
    var editing: SleepCheckIn? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [SleepPlan]
    @Query(sort: \SleepCheckIn.date, order: .reverse) private var checkIns: [SleepCheckIn]
    @AppStorage(AppStorageKey.sleepGoalMinutes) private var sleepGoalMinutes = 480

    @State private var feel: SleepFeel = .good
    @State private var quality: SleepQuality = .sound
    @State private var hours: Double = 8
    @State private var factors: Set<SleepFactor> = []
    @State private var notes: String = ""
    @State private var didLoad = false
    @State private var saveCount = 0

    private var target: SleepCheckIn? {
        editing ?? checkIns.first { Calendar.current.isDateInToday($0.date) }
    }

    private var goalHours: Double {
        Double(sleepGoalMinutes) / 60.0
    }

    private var previewScore: Int {
        SleepScoring.score(feel: feel, quality: quality, hours: hours, goalHours: goalHours)
    }

    private var saveTitle: LocalizedStringKey {
        target == nil ? "Save Check-In" : "Update Check-In"
    }

    private var dateText: String {
        (target?.date ?? .now).formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NightBackground(mood: .insights)

                ScrollView {
                    VStack(spacing: 16) {
                        scoreHero
                        feelSection
                        qualitySection
                        durationSection
                        factorsSection
                        notesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(target == nil ? "Morning Check-In" : "Update Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.lavendar)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .safeAreaInset(edge: .bottom) {
                OnboardingForwardButton(title: saveTitle, systemImage: "checkmark") {
                    save()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background {
                    LinearGradient(
                        colors: [Color.midnightNavy.opacity(0), Color.midnightNavy.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            }
        }
        .sensoryFeedback(.success, trigger: saveCount)
        .onAppear(perform: loadInitialValues)
    }

    // MARK: - Score Hero

    private var scoreHero: some View {
        HStack(spacing: 18) {
            ScoreRing(score: previewScore, lineWidth: 9, numberSize: 32)
                .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 4) {
                Text(dateText)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.lavendar.opacity(0.8))

                Text(SleepScoring.label(for: previewScore))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.interpolate)
                    .animation(.snappy, value: previewScore)

                Text("Your score updates as you answer.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.7))
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .nightCard(cornerRadius: 30, tint: Color.dreamPurple, elevated: true)
    }

    // MARK: - Feel

    private var feelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("How do you feel?")

            HStack(spacing: 8) {
                ForEach(SleepFeel.allCases) { option in
                    let isSelected = feel == option

                    Button {
                        withAnimation(.snappy) {
                            feel = option
                        }
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: option.icon)
                                .font(.system(size: 21, weight: .semibold))
                                .symbolEffect(.bounce, value: isSelected)

                            Text(option.rawValue)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(isSelected ? Color.midnightNavy : Color.white)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background {
                            selectionBackground(isSelected: isSelected, cornerRadius: 18)
                        }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: feel)
        }
        .padding(18)
        .nightCard(cornerRadius: 28)
    }

    // MARK: - Quality

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("How did you sleep?")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(SleepQuality.allCases) { option in
                    let isSelected = quality == option

                    Button {
                        withAnimation(.snappy) {
                            quality = option
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: option.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.midnightNavy : Color.starlightGold)

                            Text(option.rawValue)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.midnightNavy : Color.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 52)
                        .background {
                            selectionBackground(isSelected: isSelected, cornerRadius: 18)
                        }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: quality)
        }
        .padding(18)
        .nightCard(cornerRadius: 28)
    }

    // MARK: - Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("Sleep duration")

                Spacer()

                Text(Int(hours * 60).durationText)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.starlightGold)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: hours))
                    .animation(.snappy, value: hours)
            }

            HStack(spacing: 12) {
                stepButton(systemImage: "minus") {
                    hours = max(3, hours - 0.5)
                }

                Slider(value: $hours, in: 3...12, step: 0.5)
                    .tint(Color.dreamPurple)

                stepButton(systemImage: "plus") {
                    hours = min(12, hours + 0.5)
                }
            }
            .sensoryFeedback(.selection, trigger: hours)

            Text(goalComparison)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Color.lavendar.opacity(0.75))
        }
        .padding(18)
        .nightCard(cornerRadius: 28)
    }

    private var goalComparison: String {
        let difference = Int(((hours - goalHours) * 60).rounded())
        let goalText = Int(goalHours * 60).durationText

        if abs(difference) < 15 {
            return "Right on your \(goalText) goal."
        }
        let amount = abs(difference).durationText
        return difference < 0
            ? "\(amount) under your \(goalText) goal."
            : "\(amount) over your \(goalText) goal."
    }

    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) {
                action()
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.lavendar)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.1)))
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(systemImage == "plus" ? "Add 30 minutes" : "Remove 30 minutes")
    }

    // MARK: - Factors

    private var factorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                sectionTitle("What shaped your night?")

                Text("Optional. Snoozly uses these to spot what helps or hurts your sleep.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.7))
            }

            FlowLayout(spacing: 8) {
                ForEach(SleepFactor.allCases) { factor in
                    let isSelected = factors.contains(factor)

                    Button {
                        withAnimation(.snappy) {
                            if isSelected {
                                factors.remove(factor)
                            } else {
                                factors.insert(factor)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: factor.icon)
                                .font(.system(size: 13, weight: .semibold))

                            Text(factor.rawValue)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? Color.midnightNavy : Color.white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(NightGradient.gold)
                                    .shadow(color: Color.starlightGold.opacity(0.4), radius: 8, y: 2)
                            } else {
                                Capsule()
                                    .fill(Color.white.opacity(0.07))
                                    .overlay {
                                        Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                    }
                            }
                        }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: factors.count)
        }
        .padding(18)
        .nightCard(cornerRadius: 28)
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Notes")

            TextField("What stood out about last night?", text: $notes, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .nightWell(cornerRadius: 18)
        }
        .padding(18)
        .nightCard(cornerRadius: 28)
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
    }

    private func selectionBackground(isSelected: Bool, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return ZStack {
            shape
                .fill(Color.white.opacity(0.07))
                .overlay {
                    shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                }

            if isSelected {
                shape
                    .fill(NightGradient.lavender)
                    .overlay {
                        shape.strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                    }
                    .shadow(color: Color.dreamPurple.opacity(0.5), radius: 10, y: 4)
            }
        }
    }

    // MARK: - Load & Save

    private func loadInitialValues() {
        guard !didLoad else { return }
        didLoad = true

        if let existing = target {
            feel = existing.feelValue ?? .good
            quality = existing.qualityValue ?? .sound
            hours = min(12, max(3, (existing.hoursSlept * 2).rounded() / 2))
            factors = Set(existing.factors)
            notes = existing.notes
            return
        }

        if let planned = plannedSleepHours {
            hours = planned
        } else {
            hours = min(12, max(3, goalHours))
        }
    }

    private var plannedSleepHours: Double? {
        guard let plan = plans.first else { return nil }
        let lastNight = Weekday.today.shifted(by: -1)
        guard let night = plan.sortedNights.first(where: { $0.weekday == lastNight }), night.isEnabled else { return nil }
        let rounded = (Double(night.sleepMinutes) / 60 * 2).rounded() / 2
        return min(12, max(3, rounded))
    }

    private func save() {
        if let existing = target {
            existing.feel = feel.rawValue
            existing.sleepQuality = quality.rawValue
            existing.hoursSlept = hours
            existing.score = previewScore
            existing.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.factors = SleepFactor.allCases.filter { factors.contains($0) }
        } else {
            let checkIn = SleepCheckIn(
                date: .now,
                feel: feel.rawValue,
                sleepQuality: quality.rawValue,
                hoursSlept: hours,
                score: previewScore,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                factors: SleepFactor.allCases.filter { factors.contains($0) }
            )
            modelContext.insert(checkIn)
        }

        saveCount += 1
        dismiss()
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    CheckInSheetView()
        .modelContainer(preview.container)
}
