//
//  OnboardingPageIndicator.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI

struct OnboardingPageIndicator: View {
    let count: Int
    let current: Int

    private let spring = Animation.spring(response: 0.5, dampingFraction: 0.72)

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                dot(at: index)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .nightCard(cornerRadius: 24, blurs: false)
        .animation(spring, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Step \(current + 1) of \(count)"))
    }

    @ViewBuilder
    private func dot(at index: Int) -> some View {
        let isCurrent = index == current
        let isDone = index < current

        Capsule()
            .fill(style(isCurrent: isCurrent, isDone: isDone))
            .frame(width: isCurrent ? 28 : 7, height: 7)
            .shadow(color: isCurrent ? Color.dreamPurple.opacity(0.8) : .clear, radius: 7)
    }

    private func style(isCurrent: Bool, isDone: Bool) -> AnyShapeStyle {
        if isCurrent {
            return AnyShapeStyle(
                LinearGradient(colors: [Color.lavendar, Color.dreamPurple],
                               startPoint: .leading,
                               endPoint: .trailing)
            )
        }
        if isDone {
            return AnyShapeStyle(Color.lavendar.opacity(0.55))
        }
        return AnyShapeStyle(Color.white.opacity(0.18))
    }
}

#Preview {
    ZStack {
        Color.midnightNavy.ignoresSafeArea()
        VStack(spacing: 20) {
            OnboardingPageIndicator(count: 7, current: 0)
            OnboardingPageIndicator(count: 7, current: 2)
            OnboardingPageIndicator(count: 7, current: 6)
        }
    }
}
