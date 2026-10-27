//
//  OnboardingBackground.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI

struct OnboardingBackground: View {
    var progress: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let overscan: CGFloat = 200
    private let stars = BackdropStar.field(count: 70)

    var body: some View {
        GeometryReader { geo in
            layers
                .frame(width: geo.size.width + overscan * 2,
                       height: geo.size.height + overscan * 2)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var layers: some View {
        ZStack {
            Color.midnightNavy

            LinearGradient(
                colors: [Color.nightSurface.opacity(0), Color.nightSurface.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )

            GlowField(progress: progress, isStatic: reduceMotion)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    for star in stars {
                        let twinkle = 0.5 + 0.5 * sin(t * star.speed + star.phase)
                        let alpha = star.base + (1 - star.base) * twinkle
                        let center = CGPoint(x: star.x * size.width, y: star.y * size.height)
                        let rect = CGRect(x: center.x - star.radius,
                                          y: center.y - star.radius,
                                          width: star.radius * 2,
                                          height: star.radius * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(star.color.opacity(alpha)))
                    }
                }
            }

            RadialGradient(
                colors: [.clear, Color.black.opacity(0.35)],
                center: .center,
                startRadius: 200,
                endRadius: 560
            )
            .allowsHitTesting(false)
        }
    }
}

private struct GlowField: View, Animatable {
    var progress: CGFloat
    var isStatic: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isStatic)) { timeline in
            let t = isStatic ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let shift = Double(progress)

            ZStack {
                GlowOrb(color: .dreamPurple, opacity: 0.34, diameter: 440)
                    .offset(x: sin(t * 0.35) * 50 - 70 - shift * 70,
                            y: cos(t * 0.27) * 40 - 230)
                GlowOrb(color: .moonlightBlue, opacity: 0.16, diameter: 380)
                    .offset(x: cos(t * 0.30) * 60 + 110 - shift * 90,
                            y: sin(t * 0.22) * 50 + 260)
                GlowOrb(color: .dreamCoral, opacity: 0.10, diameter: 320)
                    .offset(x: sin(t * 0.25 + 1) * 40 - 130 - shift * 50,
                            y: cos(t * 0.33) * 40 + 190)
            }
        }
    }
}

// MARK: - Stars

private struct BackdropStar {
    let x: Double
    let y: Double
    let radius: CGFloat
    let phase: Double
    let speed: Double
    let base: Double
    let color: Color

    static func field(count: Int) -> [BackdropStar] {
        var rng = SeededGenerator(state: 0x0B0A_C0DE_5EED)
        let palette: [Color] = [.white, .lavendar, .moonlightBlue]

        return (0..<count).map { _ in
            BackdropStar(
                x: .random(in: 0...1, using: &rng),
                y: .random(in: 0...1, using: &rng),
                radius: .random(in: 0.6...1.3, using: &rng),
                phase: .random(in: 0...(2 * Double.pi), using: &rng),
                speed: .random(in: 0.8...2.2, using: &rng),
                base: .random(in: 0.10...0.28, using: &rng),
                color: palette.randomElement(using: &rng) ?? .white
            )
        }
    }
}

#Preview {
    OnboardingBackground(progress: 0)
}
