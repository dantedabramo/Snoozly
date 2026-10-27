//
//  NightTimeCard.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI

struct NightTimeCard: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    let caption: LocalizedStringKey
    let symbol: String
    var accent: Color = Color.lavendar
    var detail: LocalizedStringKey? = nil
    @Binding var isEnabled: Bool
    @Binding var minutes: Int
    let quickPicks: [Int]
    let disabledMessage: LocalizedStringKey
    let applyToAllTitle: LocalizedStringKey
    let onApplyToAll: () -> Void
    var alarm: Binding<Bool>? = nil

    @State private var applyCount = 0
    @Environment(\.onboardingDense) private var dense

    private var pickRows: [[Int]] {
        stride(from: 0, to: quickPicks.count, by: 3).map { start in
            Array(quickPicks[start..<min(start + 3, quickPicks.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: dense ? 10 : 14) {
            header

            if isEnabled {
                VStack(spacing: dense ? 8 : 12) {
                    readoutRow
                    wheel
                    quickPickSection

                    if let detail {
                        detailRow(detail)
                    }

                    if let alarm {
                        alarmRow(alarm)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            } else {
                disabledState
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
        .padding(dense ? 14 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard(cornerRadius: 28)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isEnabled)
        .sensoryFeedback(.selection, trigger: minutes)
        .sensoryFeedback(.success, trigger: applyCount)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            RowIcon(systemName: symbol, size: 40, tint: isEnabled ? accent : Color.white.opacity(0.4))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.lavendar.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            if isEnabled {
                Menu {
                    Button {
                        applyCount += 1
                        onApplyToAll()
                    } label: {
                        Label(applyToAllTitle, systemImage: "square.on.square")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.lavendar)
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More")
            }

            Toggle(isOn: $isEnabled) {
                Text(title)
            }
            .labelsHidden()
            .tint(Color.dreamPurple)
        }
    }

    // MARK: - Readout

    private var readoutRow: some View {
        HStack {
            Text(minutes.clockText)
                .font(.system(size: dense ? 34 : 40, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(NightGradient.title)
                .shadow(color: Color.dreamPurple.opacity(0.5), radius: 12)
                .contentTransition(.numericText())
                .animation(.snappy, value: minutes)

            Spacer(minLength: 8)

            Text(caption)
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(accent.opacity(0.14)))
                .overlay {
                    Capsule().strokeBorder(accent.opacity(0.3), lineWidth: 1)
                }
        }
    }

    private var wheel: some View {
        DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.colorScheme, .dark)
            .frame(height: wheelHeight)
            .clipped()
            .padding(.vertical, 4)
    }

    private var wheelHeight: CGFloat { dense ? 96 : 104 }

    // MARK: - Quick picks

    @ViewBuilder
    private var quickPickSection: some View {
        if dense {
            quickPickStrip
        } else {
            quickPickGrid
        }
    }

    private var quickPickStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(quickPicks, id: \.self) { pick in
                    quickPick(pick, fills: false)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var quickPickGrid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(pickRows.indices, id: \.self) { row in
                GridRow {
                    ForEach(pickRows[row], id: \.self) { pick in
                        quickPick(pick)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func quickPick(_ pick: Int, fills: Bool = true) -> some View {
        let isSelected = minutes == pick

        return Button {
            withAnimation(.snappy) { minutes = pick }
        } label: {
            Text(pick.clockText)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? Color.midnightNavy : Color.white)
                .padding(.horizontal, fills ? 0 : 16)
                .frame(maxWidth: fills ? CGFloat.infinity : nil, minHeight: 40)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(NightGradient.lavender)
                            .overlay {
                                Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                            }
                    } else {
                        Capsule()
                            .fill(Color.white.opacity(0.07))
                            .overlay {
                                Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            }
                    }
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .animation(.snappy, value: isSelected)
    }

    // MARK: - Detail

    private func detailRow(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 13, weight: .bold))

            Text(text)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.restfulMint)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.restfulMint.opacity(0.12))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    // MARK: - Alarm

    private func alarmRow(_ binding: Binding<Bool>) -> some View {
        SettingsRow(icon: "alarm.fill", title: "Wake-up Alarm", tint: Color.starlightGold) {
            Toggle(isOn: binding) {
                Text("Wake-up Alarm")
            }
            .labelsHidden()
            .tint(Color.dreamPurple)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, dense ? 6 : 10)
        .nightWell(cornerRadius: 18)
    }

    // MARK: - Disabled

    private var disabledState: some View {
        Text(disabledMessage)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(Color.lavendar.opacity(0.65))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 4)
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { Date.today(atMinutes: minutes) },
            set: { minutes = $0.minutesAfterMidnight }
        )
    }
}
