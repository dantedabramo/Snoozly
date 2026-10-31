//
//  CheckInDetailSheet.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-25.
//

import SwiftUI
import SwiftData

// MARK: - CheckInDetailSheet

struct CheckInDetailSheet: View {
    let checkIn: SleepCheckIn

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showEditSheet = false

    private var dateText: String {
        checkIn.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NightBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        summaryCard
                        detailsCard

                        if !checkIn.factors.isEmpty {
                            factorsCard
                        }

                        if !checkIn.notes.isEmpty {
                            notesCard
                        }

                        HoldActionButton(
                            title: "Hold to Delete Check-In",
                            systemImage: "trash.fill",
                            tint: Color.dreamCoral,
                            duration: 1.0,
                            isDestructive: true
                        ) {
                            deleteCheckIn()
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Edit") {
                        showEditSheet = true
                    }
                    .foregroundStyle(Color.lavendar)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.starlightGold)
                }
            }
            .sheet(isPresented: $showEditSheet) {
                CheckInSheetView(editing: checkIn)
            }
        }
    }

    // MARK: - Delete

    private func deleteCheckIn() {
        let context = modelContext
        let item = checkIn
        dismiss()

        Task {
            try? await Task.sleep(for: .milliseconds(450))
            context.delete(item)
        }
    }

    // MARK: - Cards

    private var summaryCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: CGFloat(checkIn.score) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [Color.lavendar, Color.dreamPurple, Color.starlightGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(checkIn.score)")
                    .scaledFont(size: 28, weight: .heavy, design: .rounded)
                    .foregroundStyle(.white)
            }
            .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 4) {
                Text(dateText)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.lavendar.opacity(0.8))

                Text(SleepScoring.label(for: checkIn.score))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text("Sleep score")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.7))
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .glassCard(cornerRadius: 26)
    }

    private var detailsCard: some View {
        VStack(spacing: 14) {
            detailRow(icon: checkIn.feelValue?.icon ?? "face.smiling", label: "Feeling", value: checkIn.feel)

            Divider().overlay(Color.white.opacity(0.08))

            detailRow(icon: checkIn.qualityValue?.icon ?? "bed.double.fill", label: "Sleep quality", value: checkIn.sleepQuality)

            Divider().overlay(Color.white.opacity(0.08))

            detailRow(icon: "clock.fill", label: "Duration", value: Int(checkIn.hoursSlept * 60).durationText)
        }
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private var factorsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What shaped your night")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            FlowLayout(spacing: 8) {
                ForEach(checkIn.factors) { factor in
                    HStack(spacing: 6) {
                        Image(systemName: factor.icon)
                            .font(.system(size: 12, weight: .semibold))

                        Text(factor.rawValue)
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(Color.midnightNavy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.starlightGold))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text(checkIn.notes)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.lavendar.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private func detailRow(icon: String, label: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.starlightGold)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.midnightNavy.opacity(0.6)))

            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.lavendar.opacity(0.85))

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}
