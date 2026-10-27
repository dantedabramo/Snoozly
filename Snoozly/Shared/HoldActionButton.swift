//
//  HoldActionButton.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-25.
//

import SwiftUI

// MARK: - HoldActionButton

struct HoldActionButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var tint: Color = Color.dreamPurple
    var duration: Double = 0.8
    var isDestructive: Bool = false
    var isHighlighted: Bool = false
    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var isPressing = false
    @State private var didComplete = false
    @State private var pressStart: Date?
    @State private var stage = 0
    @State private var completions = 0
    @State private var tickTask: Task<Void, Never>?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    private var fillGradient: LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.85), (isDestructive ? Color.dreamCoral : Color.lavendar).opacity(0.55)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        ZStack(alignment: .leading) {
            shape
                .fill(Color.white.opacity(isHighlighted ? 0.12 : 0.07))

            GeometryReader { geo in
                Rectangle()
                    .fill(fillGradient)
                    .frame(width: geo.size.width * progress)
            }
            .clipShape(shape)

            HStack(spacing: 12) {
                Image(systemName: didComplete ? "checkmark.circle.fill" : systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(didComplete || isHighlighted ? Color.starlightGold : Color.white)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: completions)

                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                Text(hintText)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                    .contentTransition(.interpolate)
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 58)
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(isPressing ? 0.35 : 0.16), Color.white.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .contentShape(shape)
        .scaleEffect(isPressing ? 0.98 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressing)
        .animation(.snappy, value: didComplete)
        .onLongPressGesture(minimumDuration: duration, maximumDistance: 60, perform: {
            complete()
        }, onPressingChanged: { pressing in
            pressingChanged(pressing)
        })
        .sensoryFeedback(.selection, trigger: isPressing) { _, pressing in pressing }
        .sensoryFeedback(trigger: stage) { oldValue, newValue in
            guard newValue > oldValue else { return nil }
            return .impact(weight: .light, intensity: 0.35 + 0.15 * Double(newValue))
        }
        .sensoryFeedback(isDestructive ? .warning : .success, trigger: completions)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint("Press and hold to confirm")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            complete()
        }
    }

    private var hintText: LocalizedStringKey {
        if didComplete { return "Done" }
        return isPressing ? "Keep holding" : "Hold"
    }

    // MARK: - Hold Logic

    private func pressingChanged(_ pressing: Bool) {
        if pressing {
            guard !didComplete else { return }
            isPressing = true
            pressStart = Date()
            stage = 0
            withAnimation(.linear(duration: duration)) {
                progress = 1
            }
            startTicks()
        } else {
            tickTask?.cancel()
            isPressing = false
            let held = pressStart.map { Date().timeIntervalSince($0) } ?? 0
            pressStart = nil
            if !didComplete && held < duration - 0.05 {
                withAnimation(.easeOut(duration: 0.25)) {
                    progress = 0
                }
            }
        }
    }

    private func startTicks() {
        tickTask?.cancel()
        let interval = duration / 4
        tickTask = Task {
            for step in 1...4 {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { return }
                stage = step
            }
        }
    }

    private func complete() {
        guard !didComplete else { return }
        didComplete = true
        tickTask?.cancel()
        completions += 1
        progress = 1
        onComplete()

        Task {
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.3)) {
                progress = 0
            }
            didComplete = false
        }
    }
}

#Preview {
    ZStack {
        Color.midnightNavy.ignoresSafeArea()
        VStack(spacing: 16) {
            HoldActionButton(title: "Hold to Skip Tonight", systemImage: "moon.zzz.fill") {}
            HoldActionButton(title: "Hold to Delete", systemImage: "trash.fill", tint: Color.dreamCoral, isDestructive: true) {}
        }
        .padding(24)
    }
}
