//
//  GlowOrb.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import SwiftUI

struct GlowOrb: View {
    let color: Color
    let opacity: Double
    let diameter: CGFloat

    var body: some View {
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
}
