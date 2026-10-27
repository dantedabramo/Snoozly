//
//  NightSurface.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-26.
//

import SwiftUI

// MARK: - NightCard

private struct NightCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let elevated: Bool
    let blurs: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let washTop = (tint ?? Color.lavendar).opacity(tint == nil ? 0.08 : 0.32)
        let washBottom = Color.nightSurface.opacity(tint == nil ? 0.62 : 0.42)

        content
            .background {
                ZStack {
                    if blurs {
                        shape.fill(.ultraThinMaterial)
                    }

                    shape.fill(
                        LinearGradient(
                            colors: [washTop, washBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                    shape.fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.07), Color.white.opacity(0)],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.45)
                        )
                    )
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.26), Color.white.opacity(0.05), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: Color.black.opacity(elevated ? 0.38 : 0.24),
                    radius: elevated ? 26 : 16,
                    y: elevated ? 16 : 9)
    }
}

extension View {
    func nightCard(cornerRadius: CGFloat = 26,
                   tint: Color? = nil,
                   elevated: Bool = false,
                   blurs: Bool = true) -> some View {
        modifier(NightCardModifier(cornerRadius: cornerRadius, tint: tint, elevated: elevated, blurs: blurs))
    }

    func nightWell(cornerRadius: CGFloat = 16) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

// MARK: - Gradients

enum NightGradient {
    static var lavender: LinearGradient {
        LinearGradient(colors: [Color.lavendar, Color.dreamPurple],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    static var gold: LinearGradient {
        LinearGradient(colors: [Color.starlightGold, Color.starlightGold.opacity(0.78)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    static var night: LinearGradient {
        LinearGradient(colors: [Color.dreamPurple, Color.lavendar, Color.starlightGold],
                       startPoint: .leading,
                       endPoint: .trailing)
    }

    static var title: LinearGradient {
        LinearGradient(colors: [Color.white, Color.lavendar],
                       startPoint: .top,
                       endPoint: .bottom)
    }
}

// MARK: - ScoreTone

enum ScoreTone {
    static func color(for score: Int) -> Color {
        switch score {
        case 80...: Color.restfulMint
        case 65..<80: Color.lavendar
        case 50..<65: Color.starlightGold
        default: Color.dreamCoral
        }
    }
}

// MARK: - ScoreRing

struct ScoreRing: View {
    let score: Int?
    var lineWidth: CGFloat = 8
    var numberSize: CGFloat = 28

    private var progress: Double {
        min(max(Double(score ?? 0) / 100, 0), 1)
    }

    private var ringGradient: AngularGradient {
        let end = min(max(progress, 0.05), 0.97)

        return AngularGradient(
            gradient: Gradient(stops: [
                .init(color: Color.moonlightBlue, location: 0),
                .init(color: Color.lavendar, location: end * 0.55),
                .init(color: Color.dreamPurple, location: end),
                .init(color: Color.moonlightBlue, location: 1)
            ]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(progress > 0 ? 1 : 0)
                .shadow(color: Color.dreamPurple.opacity(0.4), radius: 6)

            Text(score.map { "\($0)" } ?? "–")
                .font(.system(size: numberSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText(value: Double(score ?? 0)))
        }
        .padding(lineWidth / 2)
        .animation(.snappy, value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep score")
        .accessibilityValue(score.map { "\($0)" } ?? "No data")
    }
}

// MARK: - ScreenHeader

struct ScreenHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let trailing: Trailing

    init(_ title: LocalizedStringKey,
         subtitle: LocalizedStringKey? = nil,
         @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 8)

                trailing
            }

            if let subtitle {
                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - SectionTitle

struct SectionTitle: View {
    let title: LocalizedStringKey
    let showsPro: Bool

    init(_ title: LocalizedStringKey, showsPro: Bool = false) {
        self.title = title
        self.showsPro = showsPro
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            if showsPro {
                ProTag()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - ProTag

struct ProTag: View {
    var compact: Bool = false

    var body: some View {
        Text("PRO")
            .font(.system(size: compact ? 8 : 10, weight: .black, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(Color.midnightNavy)
            .padding(.horizontal, compact ? 5 : 7)
            .padding(.vertical, compact ? 1.5 : 2.5)
            .background(Capsule().fill(NightGradient.gold))
    }
}

// MARK: - InfoChip

struct InfoChip: View {
    let icon: String
    let text: String
    var tint: Color = Color.lavendar

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))

            Text(text)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay {
            Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 1)
        }
    }
}

// MARK: - Reveal Trigger

private struct AppearRevealModifier: ViewModifier {
    @Binding var appeared: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !appeared else { return }
                appeared = true
            }
    }
}

extension View {
    func revealOnAppear(_ appeared: Binding<Bool>) -> some View {
        modifier(AppearRevealModifier(appeared: appeared))
    }
}
