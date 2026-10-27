//
//  OnboardingLayout.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI

// MARK: - Density

private struct OnboardingDenseKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var onboardingDense: Bool {
        get { self[OnboardingDenseKey.self] }
        set { self[OnboardingDenseKey.self] = newValue }
    }
}

private struct OnboardingWideKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var onboardingWide: Bool {
        get { self[OnboardingWideKey.self] }
        set { self[OnboardingWideKey.self] = newValue }
    }
}

// MARK: - Container

struct OnboardingPageContainer<Content: View>: View {
    var centersContent: Bool = false
    @ViewBuilder var content: () -> Content

    private var alignment: Alignment { centersContent ? .center : .top }
    @Environment(\.onboardingWide) private var isWide

    var body: some View {
        GeometryReader { geo in
            ViewThatFits(in: .vertical) {
                padded(dense: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)

                padded(dense: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)

                ScrollView {
                    padded(dense: true)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: alignment)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .contentMargins(.bottom, 20, for: .scrollContent)
                .mask(alignment: .bottom) { bottomFade }
            }
        }
    }

    private var bottomFade: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.black)

            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 32)
        }
    }

    private func padded(dense: Bool) -> some View {
        content()
            .environment(\.onboardingDense, dense)
            .frame(maxWidth: isWide ? 920 : 520)
            .padding(.horizontal, 24)
            .padding(.vertical, dense ? 4 : 12)
    }
}

struct OnboardingHeadline: View {
    var eyebrow: LocalizedStringKey? = nil
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey
    var centered: Bool = false
    var prominent: Bool = false

    @Environment(\.onboardingDense) private var dense

    private var titleStyle: Font.TextStyle {
        if dense { return prominent ? .title : .title2 }
        return prominent ? .largeTitle : .title
    }

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: dense ? 4 : (prominent ? 12 : 8)) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(Color.lavendar)
            }

            Text(title)
                .font(.system(titleStyle, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(prominent ? .body : .callout, design: .rounded))
                .foregroundStyle(Color.lavendar.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(centered ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
        .accessibilityElement(children: .combine)
    }
}

struct OnboardingHint: View {
    var text: LocalizedStringKey
    var symbol: String = "info.circle"

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Color.dreamCoral)
            .fixedSize(horizontal: false, vertical: true)
    }
}
