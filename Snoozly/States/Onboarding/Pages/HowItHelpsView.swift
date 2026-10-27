//
//  HowItHelpsView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import SwiftUI

struct HowItHelpsView: View {
    var isActive: Bool
    
    @Environment(\.onboardingWide) private var pageIsWide

    private struct Item: Identifiable {
        let id: Int
        let symbol: String
        let tint: Color
        let title: LocalizedStringKey
        let text: LocalizedStringKey
    }

    private let items: [Item] = [
        Item(id: 0, symbol: "calendar", tint: Color.lavendar,
             title: "Plan your nights",
             text: "Set a bedtime and a wake-up time for every day of your week."),
        Item(id: 1, symbol: "bell.badge.fill", tint: Color.starlightGold,
             title: "Wind down gently",
             text: "A soft reminder when it's time to slow down."),
        Item(id: 2, symbol: "hourglass", tint: Color.moonlightBlue,
             title: "Quiet your apps",
             text: "Block the apps that keep you scrolling, only at night."),
        Item(id: 3, symbol: "sunrise.fill", tint: Color.dreamCoral,
             title: "Wake up your way",
             text: "Optional alarms with the snooze that suits you.")
    ]

    var body: some View {
        OnboardingPageContainer(centersContent: true) {
            let isWide = pageIsWide
            let layout = isWide
                ? AnyLayout(HStackLayout(alignment: .center, spacing: 28))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))

            layout {
                VStack(alignment: .leading, spacing: 20) {
                    OnboardingHeadline(
                        title: "Here's how Snoozly helps.",
                        subtitle: "A calm routine, built around your real week."
                    )
                    .reveal(isActive, delay: 0.05)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(items) { item in
                        row(item)
                            .reveal(isActive, delay: 0.2 + Double(item.id) * 0.09)
                    }
                }
                .padding(18)
                .frame(maxWidth: 560, alignment: .leading)
                .nightCard(cornerRadius: 28)
                .reveal(isActive, delay: 0.15, offset: 26)
            }
        }
    }

    private func row(_ item: Item) -> some View {
        HStack(spacing: 14) {
            RowIcon(systemName: item.symbol, size: 46, tint: item.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)

                Text(item.text)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack {
        NightBackground()
        HowItHelpsView(isActive: true)
            .padding()
    }
}
