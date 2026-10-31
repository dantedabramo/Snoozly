//
//  HoldProgressButton.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-23.
//

import SwiftUI
import AudioToolbox

// MARK: - HoldProgressButton

struct HoldProgressButton: View {
    let title: String
    let activeTitle: String
    let isActive: Bool
    let icon: String
    let activeIcon: String
    let onComplete: () -> Void

    @State private var isHolding = false
    @State private var progress: CGFloat = 0.0
    @State private var showHint = false

    private let holdDuration: Double = 0.75

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(isActive ? 0.12 : 0.07))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        }

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.dreamPurple.opacity(0.55), Color.lavendar.opacity(0.45)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)

                    HStack(spacing: 10) {
                        Image(systemName: isActive ? activeIcon : icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isActive ? Color.starlightGold : .white)

                        Text(isActive ? activeTitle : title)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)

                        Spacer()

                        Text(isHolding ? "\(Int(progress * 100))%" : "Hold")
                            .scaledFont(size: 11, weight: .heavy, design: .rounded)
                            .foregroundStyle(Color.lavendar.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 52)
                .contentShape(RoundedRectangle(cornerRadius: 18))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isHolding {
                                startHold()
                            }
                        }
                        .onEnded { _ in
                            cancelHold()
                        }
                )
            }
            .frame(height: 52)

            if showHint {
                Text("Press and hold to confirm")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.starlightGold.opacity(0.9))
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Hold Logic

    private func startHold() {
        isHolding = true
        showHint = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.linear(duration: holdDuration)) {
            progress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
            if isHolding && progress >= 0.99 {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onComplete()
                resetState()
            }
        }
    }

    private func cancelHold() {
        if isHolding && progress < 0.99 {
            showHint = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showHint = false
                }
            }
        }
        resetState()
    }

    private func resetState() {
        isHolding = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            progress = 0.0
        }
    }
}
