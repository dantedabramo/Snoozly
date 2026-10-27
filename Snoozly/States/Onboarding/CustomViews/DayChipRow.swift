//
//  DayChipRow.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI

struct DayChipRow: View {
    let nights: [NightPlan]
    @Binding var selection: Weekday
    let subtitle: (NightPlan) -> String

    @Namespace private var highlight

    private let today = Weekday.today

    var body: some View {
        HStack(spacing: 6) {
            ForEach(nights) { night in
                chip(for: night)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chip(for night: NightPlan) -> some View {
        let day = night.weekday
        let isSelected = day == selection
        let isToday = day == today
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.74)) {
                selection = day
            }
        } label: {
            VStack(spacing: 6) {
                Text(day.initial)
                    .font(.system(.headline, design: .rounded, weight: .heavy))

                Text(night.isEnabled ? subtitle(night) : "Off")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(0.9)

                Circle()
                    .fill(isSelected ? Color.midnightNavy : Color.starlightGold)
                    .frame(width: 4, height: 4)
                    .opacity(isToday ? 1 : 0)
            }
            .foregroundStyle(foreground(isSelected: isSelected, isEnabled: night.isEnabled))
            .frame(maxWidth: .infinity, minHeight: 70)
            .background {
                ZStack {
                    shape
                        .fill(Color.white.opacity(night.isEnabled ? 0.07 : 0.03))
                        .overlay {
                            shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }

                    if isSelected {
                        shape
                            .fill(NightGradient.lavender)
                            .overlay {
                                shape.strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                            }
                            .shadow(color: Color.dreamPurple.opacity(0.5), radius: 10, y: 4)
                            .matchedGeometryEffect(id: "highlight", in: highlight)
                    }
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(Text(verbatim: day.fullName))
        .accessibilityValue(night.isEnabled ? Text(verbatim: subtitle(night)) : Text("Off"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func foreground(isSelected: Bool, isEnabled: Bool) -> Color {
        if isSelected { return Color.midnightNavy }
        return isEnabled ? Color.white : Color.white.opacity(0.4)
    }
}
