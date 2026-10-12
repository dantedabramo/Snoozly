//
//  SplashView.swift
//  Snoozle
//
//  Created by Dante D’Abramo on 2026-10-12.
//

import SwiftUI

struct SplashView: View {

    var hold: Double = 3.0

    var onFinish: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Intro state
    @State private var startDate = Date()
    @State private var starsIn = false
    @State private var iconIn = false
    @State private var ringsOut = false
    @State private var wordIn = false
    @State private var taglineIn = false
    @State private var landed = false

    // MARK: - Exit state
    @State private var isExiting = false

    private let word = Array("Snoozly")
    private let stars = Star.makeField(count: 78)

    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSince(startDate)

                ZStack {
                    background(t: t, keepOut: textKeepOut(in: geo))
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        Spacer()
                        hero(t: t)
                        wordmark
                            .padding(.top, 44)
                        tagline
                            .padding(.top, 14)
                        Spacer()
                        Spacer()
                    }
                    shootingStarOverlay(t: t, size: geo.size)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .opacity(isExiting ? 0 : 1)
        .scaleEffect(isExiting ? 1.06 : 1)
        .blur(radius: isExiting ? 8 : 0)
        .animation(.easeInOut(duration: 0.75), value: isExiting)
        .task { await runIntro() }
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.95), trigger: landed)
        .sensoryFeedback(.selection, trigger: wordIn)
        .sensoryFeedback(.success, trigger: taglineIn)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Snoozle")
    }

    // MARK: - Intro timeline
    private func runIntro() async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.6)) {
                starsIn = true
                iconIn = true
                ringsOut = true
                wordIn = true
                taglineIn = true
            }
        } else {
            withAnimation(.easeIn(duration: 1.4)) { starsIn = true }

            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.spring(response: 1.0, dampingFraction: 0.58)) { iconIn = true }

            try? await Task.sleep(for: .milliseconds(450))
            landed.toggle()
            ringsOut = true

            try? await Task.sleep(for: .milliseconds(250))
            wordIn = true

            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.8)) { taglineIn = true }
        }

        try? await Task.sleep(for: .seconds(hold))
        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: 0.75)) {
            isExiting = true
        }

        try? await Task.sleep(for: .milliseconds(750))
        guard !Task.isCancelled else { return }

        onFinish()
    }

    // MARK: - Layout helpers
    private func textKeepOut(in geo: GeometryProxy) -> CGRect {
        let blockHeight: CGFloat = 340
        let top = geo.safeAreaInsets.top + (geo.size.height - blockHeight) / 3
        return CGRect(x: geo.size.width / 2 - 165,
                      y: top + 240,
                      width: 330,
                      height: blockHeight - 240 + 8)
    }

    // MARK: - Background
    private func background(t: Double, keepOut: CGRect) -> some View {
        ZStack {
            Color.midnightNavy

            LinearGradient(
                colors: [Color.nightSurface.opacity(0), Color.nightSurface.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Slow-drifting aurora glows
            glow(.dreamPurple, opacity: 0.34, diameter: 440)
                .offset(x: sin(t * 0.35) * 50 - 70, y: cos(t * 0.27) * 40 - 230)
            glow(.moonlightBlue, opacity: 0.16, diameter: 380)
                .offset(x: cos(t * 0.30) * 60 + 110, y: sin(t * 0.22) * 50 + 260)
            glow(.dreamCoral, opacity: 0.10, diameter: 320)
                .offset(x: sin(t * 0.25 + 1) * 40 - 130, y: cos(t * 0.33) * 40 + 190)

            Canvas { context, size in
                drawSky(&context, size: size, t: t, keepOut: keepOut)
            }
            .opacity(starsIn ? 1 : 0)

            RadialGradient(
                colors: [.clear, Color.black.opacity(0.35)],
                center: .center,
                startRadius: 200,
                endRadius: 560
            )
            .allowsHitTesting(false)
        }
    }

    private func glow(_ color: Color, opacity: Double, diameter: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(opacity), color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
    }

    // MARK: - Sky drawing
    private func drawSky(_ context: inout GraphicsContext, size: CGSize, t: Double, keepOut: CGRect) {
        for star in stars {
            let twinkle = 0.5 + 0.5 * sin(t * star.speed + star.phase)
            let alpha = star.base + (1 - star.base) * twinkle
            let centre = CGPoint(x: star.x * size.width, y: star.y * size.height)
            if keepOut.contains(centre) { continue }
            let color = star.color.opacity(alpha)

            let rect = CGRect(x: centre.x - star.radius, y: centre.y - star.radius,
                              width: star.radius * 2, height: star.radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }

    }

    private func shootingStarOverlay(t: Double, size: CGSize) -> some View {
        Canvas { context, _ in
            let first = 1.0, cycle = 4.6, duration = 0.8
            guard t > first else { return }
            let elapsed = t - first
            let local = elapsed.truncatingRemainder(dividingBy: cycle)
            guard local < duration else { return }

            let p = local / duration
            let mirrored = Int(elapsed / cycle) % 2 == 1
            let from = CGPoint(x: size.width * (mirrored ? 0.88 : 0.12), y: size.height * 0.10)
            let to = CGPoint(x: size.width * (mirrored ? 0.38 : 0.62), y: size.height * 0.30)

            func point(_ q: Double) -> CGPoint {
                CGPoint(x: from.x + (to.x - from.x) * q, y: from.y + (to.y - from.y) * q)
            }

            let head = point(p)
            let tail = point(max(0, p - 0.22))
            let fade = sin(p * .pi)

            var trail = Path()
            trail.move(to: tail)
            trail.addLine(to: head)

            context.stroke(
                trail,
                with: .linearGradient(
                    Gradient(colors: [Color.starlightGold.opacity(0), Color.starlightGold.opacity(fade)]),
                    startPoint: tail,
                    endPoint: head
                ),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: head.x - 2.2, y: head.y - 2.2, width: 4.4, height: 4.4)),
                with: .color(Color.white.opacity(fade))
            )
        }
        .allowsHitTesting(false)
        .opacity(starsIn ? 1 : 0)
    }

    // MARK: - Hero (icon, halo, rings, z's)
    private func hero(t: Double) -> some View {
        let breathe = sin(t * 1.5)
        let bob = sin(t * 1.2) * 6

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.dreamPurple.opacity(0.65),
                            Color.dreamPurple.opacity(0.18),
                            Color.dreamPurple.opacity(0)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 190
                    )
                )
                .frame(width: 380, height: 380)
                .scaleEffect(1 + breathe * 0.06)
                .opacity(iconIn ? 1 : 0)

            if ringsOut && !reduceMotion {
                PulseRing(delay: 0)
                PulseRing(delay: 0.3)
            }

            floatingZs(t: t)

            Image("SplashIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .shadow(color: Color.dreamPurple.opacity(0.55), radius: 36, y: 14)
                .scaleEffect(1 + breathe * 0.012)
                .offset(y: bob)
                .scaleEffect(iconIn ? 1 : 0.55)
                .rotationEffect(.degrees(iconIn ? 0 : -8))
                .blur(radius: iconIn ? 0 : 18)
                .opacity(iconIn ? 1 : 0)
        }
        .frame(width: 200, height: 200)
    }

    private func floatingZs(t: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let p = (t * 0.32 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Text("z")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(i == 1 ? Color.starlightGold : Color.lavendar)
                    .scaleEffect(0.6 + p * 0.9)
                    .rotationEffect(.degrees(-12 + p * 24))
                    .offset(x: 120 + p * 34 + sin(p * 6 + Double(i)) * 4, y: 14 - p * 124)
                    .opacity(sin(p * .pi) * 0.9)
            }
        }
        .opacity(wordIn ? 1 : 0)
        .animation(.easeIn(duration: 0.6), value: wordIn)
        .accessibilityHidden(true)
    }

    // MARK: - Wordmark & tagline
    private var wordmark: some View {
        HStack(spacing: 1) {
            ForEach(Array(word.enumerated()), id: \.offset) { index, letter in
                Text(String(letter))
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(letterStyle(isZ: letter == "z"))
                    .opacity(wordIn ? 1 : 0)
                    .offset(y: wordIn ? 0 : 22)
                    .blur(radius: wordIn ? 0 : 10)
                    .animation(
                        .spring(response: 0.7, dampingFraction: 0.72).delay(Double(index) * 0.06),
                        value: wordIn
                    )
            }
        }
        .shadow(color: Color.dreamPurple.opacity(0.6), radius: 18)
    }

    private func letterStyle(isZ: Bool) -> AnyShapeStyle {
        if isZ {
            return AnyShapeStyle(
                LinearGradient(colors: [Color.starlightGold, Color.starlightGold.opacity(0.75)],
                               startPoint: .top, endPoint: .bottom)
            )
        }
        return AnyShapeStyle(
            LinearGradient(colors: [Color.white, Color.lavendar],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private var tagline: some View {
        Text("Sweet dreams start here")
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .tracking(2.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.moonlightBlue.opacity(0.85))
            .opacity(taglineIn ? 1 : 0)
            .offset(y: taglineIn ? 0 : 8)
    }
}

// MARK: - Pulse ring
private struct PulseRing: View {
    var delay: Double
    @State private var go = false

    var body: some View {
        Circle()
            .strokeBorder(Color.lavendar.opacity(0.55), lineWidth: 1.5)
            .frame(width: 200, height: 200)
            .scaleEffect(go ? 2.4 : 0.9)
            .opacity(go ? 0 : 0.8)
            .onAppear {
                withAnimation(.easeOut(duration: 1.7).delay(delay)) { go = true }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Star field
private struct Star {
    let x: Double
    let y: Double
    let radius: CGFloat
    let phase: Double
    let speed: Double
    let base: Double
    let isSparkle: Bool
    let color: Color

    static func makeField(count: Int) -> [Star] {
        var rng = SeededGenerator(state: 0x5EED_5100_22)
        let palette: [Color] = [.starlightGold, .lavendar, .moonlightBlue, .white]

        return (0..<count).map { _ in
            let sparkle = false
            return Star(
                x: .random(in: 0...1, using: &rng),
                y: .random(in: 0...1, using: &rng),
                radius: sparkle ? CGFloat.random(in: 4...8, using: &rng) : CGFloat.random(in: 0.7...1.7, using: &rng),
                phase: Double.random(in: 0...(2 * Double.pi), using: &rng),
                speed: .random(in: 0.8...2.4, using: &rng),
                base: .random(in: 0.15...0.45, using: &rng),
                isSparkle: sparkle,
                color: palette.randomElement(using: &rng) ?? .white
            )
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

#Preview {
    SplashView()
}
