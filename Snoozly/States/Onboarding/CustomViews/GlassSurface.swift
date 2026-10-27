//
//  GlassSurface.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-13.
//

import SwiftUI

// MARK: - Glass

private struct SnoozGlass<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?

    func body(content: Content) -> some View {
        content.glassEffect(glass, in: shape)
    }

    private var glass: Glass {
        if let tint {
            return Glass.regular.tint(tint)
        }
        return Glass.regular
    }
}

extension View {
    func snoozGlass<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        modifier(SnoozGlass(shape: shape, tint: tint))
    }

    func glassCard(cornerRadius: CGFloat = 28) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .snoozGlass(in: shape, tint: Color.nightSurface.opacity(0.55))
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.03)],
                                   startPoint: .top,
                                   endPoint: .bottom),
                    lineWidth: 1
                )
            }
            .shadow(color: Color.black.opacity(0.25), radius: 18, y: 10)
    }
}

// MARK: - Reveal

private struct RevealModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double
    let offset: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: (reduceMotion || isVisible) ? 0 : offset)
            .blur(radius: (reduceMotion || isVisible) ? 0 : 8)
            .animation(animation, value: isVisible)
    }

    private var animation: Animation {
        if reduceMotion {
            return .easeOut(duration: 0.2)
        }
        return isVisible
            ? .spring(response: 0.7, dampingFraction: 0.82).delay(delay)
            : .easeOut(duration: 0.15)
    }
}

extension View {
    func reveal(_ isVisible: Bool, delay: Double = 0, offset: CGFloat = 18) -> some View {
        modifier(RevealModifier(isVisible: isVisible, delay: delay, offset: offset))
    }
}
