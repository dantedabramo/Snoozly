//
//  ScaledFont.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-30.
//

import SwiftUI

// MARK: - ScaledFont

private struct ScaledFont: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight, design: design))
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design))
    }

    func accessibleSpacing() -> some View {
        modifier(AccessibleSpacing())
    }
}

// MARK: - AccessibleSpacing

private struct AccessibleSpacing: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 6 : 0)
    }
}

// MARK: - AdaptiveStack

struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat = 12
    var verticalAlignment: VerticalAlignment = .top
    var horizontalAlignment: HorizontalAlignment = .leading
    @ViewBuilder var content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: horizontalAlignment, spacing: spacing, content: content)
        } else {
            HStack(alignment: verticalAlignment, spacing: spacing, content: content)
        }
    }
}
