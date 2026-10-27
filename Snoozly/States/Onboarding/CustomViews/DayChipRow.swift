//
//  DayChipRow.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI

struct DayChipRow<Item: Identifiable>: View {
    let items: [Item]
    @Binding var selection: Weekday
    let day: (Item) -> Weekday
    let isEnabled: (Item) -> Bool
    let subtitle: (Item) -> String

    @Namespace private var highlight

    private let today = Weekday.today

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                chip(for: item)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chip(for item: Item) -> some View {
        let itemDay = day(item)
        let isSelected = itemDay == selection
        let isToday = itemDay == today
        let active = isEnabled(item)
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.74)) {
                selection = itemDay
            }
        } label: {
            VStack(spacing: 6) {
                Text(itemDay.initial)
                    .font(.system(.headline, design: .rounded, weight: .heavy))

                Text(active ? subtitle(item) : "Off")
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
            .foregroundStyle(foreground(isSelected: isSelected, isEnabled: active))
            .frame(maxWidth: .infinity, minHeight: 70)
            .background {
                ZStack {
                    shape
                        .fill(Color.white.opacity(active ? 0.07 : 0.03))
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
        .accessibilityLabel(Text(verbatim: itemDay.fullName))
        .accessibilityValue(active ? Text(verbatim: subtitle(item)) : Text("Off"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func foreground(isSelected: Bool, isEnabled: Bool) -> Color {
        if isSelected { return Color.midnightNavy }
        return isEnabled ? Color.white : Color.white.opacity(0.4)
    }
}

extension DayChipRow where Item == NightPlan {
    init(nights: [NightPlan], selection: Binding<Weekday>, subtitle: @escaping (NightPlan) -> String) {
        self.items = nights
        self._selection = selection
        self.day = { $0.weekday }
        self.isEnabled = { $0.isEnabled }
        self.subtitle = subtitle
    }
}
