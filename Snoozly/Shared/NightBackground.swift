//
//  NightBackground.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-25.
//

import SwiftUI

// MARK: - NightMood

enum NightMood {
    case calm
    case tonight
    case schedule
    case insights
    case settings

    fileprivate var primary: Color {
        switch self {
        case .calm, .tonight, .insights, .settings: Color.dreamPurple
        case .schedule: Color.moonlightBlue
        }
    }

    fileprivate var secondary: Color {
        switch self {
        case .calm, .tonight, .settings: Color.moonlightBlue
        case .schedule: Color.dreamPurple
        case .insights: Color.restfulMint
        }
    }

    fileprivate var accent: Color {
        switch self {
        case .calm: Color.dreamCoral
        case .tonight: Color.starlightGold
        case .schedule: Color.dreamCoral
        case .insights: Color.moonlightBlue
        case .settings: Color.lavendar
        }
    }

    fileprivate var primaryStrength: Double {
        self == .settings ? 0.26 : 0.38
    }

    fileprivate var accentStrength: Double {
        self == .tonight ? 0.14 : 0.09
    }
}

// MARK: - NightBackground

struct NightBackground: View {
    var mood: NightMood = .calm

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.midnightNavy

                LinearGradient(
                    colors: [Color.nightSurface.opacity(0.55), Color.midnightNavy, Color.black.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                GlowOrb(color: mood.primary, opacity: mood.primaryStrength, diameter: 560)
                    .position(x: geo.size.width * 0.12, y: geo.size.height * 0.02)

                GlowOrb(color: mood.secondary, opacity: 0.15, diameter: 460)
                    .position(x: geo.size.width * 1.0, y: geo.size.height * 0.46)

                GlowOrb(color: mood.accent, opacity: mood.accentStrength, diameter: 420)
                    .position(x: geo.size.width * 0.06, y: geo.size.height * 0.98)

                StarField()

                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.32)],
                    center: .center,
                    startRadius: 220,
                    endRadius: 640
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - StarField

private struct StarField: View {
    private static let stars = Star.field(count: 48)

    var body: some View {
        let stars = Self.stars

        Canvas { context, size in
            for star in stars {
                let center = CGPoint(x: star.x * size.width, y: star.y * size.height)

                let rect = CGRect(x: center.x - star.radius,
                                  y: center.y - star.radius,
                                  width: star.radius * 2,
                                  height: star.radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(star.color.opacity(star.alpha)))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Star {
    let x: Double
    let y: Double
    let radius: CGFloat
    let alpha: Double
    let color: Color
    let isBright: Bool

    static func field(count: Int) -> [Star] {
        var rng = SeededGenerator(state: 0x5EED_4B1D_2026_1026)
        let palette: [Color] = [.white, .white, .lavendar, .moonlightBlue]

        return (0..<count).map { index in
            let bright = index % 14 == 0
            let x = Double.random(in: 0...1, using: &rng)
            let y = Double.random(in: 0...1, using: &rng)
            let radiusRange: ClosedRange<CGFloat> = bright ? 0.9...1.4 : 0.5...1.1
            let alphaRange: ClosedRange<Double> = bright ? 0.25...0.40 : 0.12...0.28
            let radius = CGFloat.random(in: radiusRange, using: &rng)
            let alpha = Double.random(in: alphaRange, using: &rng)
            let color = palette.randomElement(using: &rng) ?? Color.white

            return Star(x: x, y: y, radius: radius, alpha: alpha, color: color, isBright: bright)
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }

        return CGSize(width: usedWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
