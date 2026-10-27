//
//  SleepyCreatureView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import SwiftUI

struct SleepyCreatureView: View {
    var showStars: Bool = true
    var breathDuration: Double = 2.0

    @State private var inhaled = false
    @State private var twinkle = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let canvas: CGFloat = 880
    private let tail  = UnitPoint(x: (845 - 80) / 880.0, y: (440 - 80) / 880.0)

    private var breath: Animation {
        .easeInOut(duration: breathDuration).repeatForever(autoreverses: true)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if showStars {
                    layer("CreatureStars")
                        .opacity(twinkle ? 1.0 : 0.5)
                        .animation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true), value: twinkle)
                }

                ZStack {
                    layer("CreatureBody")

                    ZStack {
                        layer("CreatureHat")
                        layer("CreaturePompom")
                            .rotationEffect(.degrees(inhaled ? -3 : 3), anchor: tail)
                            .animation(breath.delay(0.25), value: inhaled)
                    }

                    layer("CreatureFace")
                }
                .scaleEffect(x: inhaled ? 1.03 : 0.98,
                             y: inhaled ? 1.025 : 0.98,
                             anchor: .center)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(breath, value: inhaled)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            inhaled = true
            twinkle = true
        }
    }

    private func layer(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
    }
}

#Preview {
    ZStack {
        Color.midnightNavy.ignoresSafeArea()
        SleepyCreatureView()
            .frame(width: 300, height: 300)
    }
}
