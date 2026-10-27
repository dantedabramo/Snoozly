//
//  SettingsComponents.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import SwiftUI

// MARK: - RowIcon

struct RowIcon: View {
    let systemName: String
    var size: CGFloat = 36
    var tint: Color = Color.starlightGold

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)

        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background {
                shape.fill(
                    LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.08)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
            }
            .overlay {
                shape.strokeBorder(tint.opacity(0.30), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - RowDivider

struct RowDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
            .padding(.leading, 50)
    }
}

// MARK: - SettingsSection

struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    let footer: LocalizedStringKey?
    let content: Content

    init(_ title: LocalizedStringKey,
         footer: LocalizedStringKey? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(Color.lavendar.opacity(0.7))
                .padding(.horizontal, 8)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 14) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nightCard(cornerRadius: 26)

            if let footer {
                Text(footer)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
        }
    }
}

// MARK: - SettingsRow

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let tint: Color
    let trailing: Trailing

    init(icon: String,
         title: LocalizedStringKey,
         subtitle: LocalizedStringKey? = nil,
         tint: Color = Color.starlightGold,
         @ViewBuilder trailing: () -> Trailing) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            RowIcon(systemName: icon, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.lavendar.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            trailing
        }
        .contentShape(Rectangle())
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(icon: String,
         title: LocalizedStringKey,
         subtitle: LocalizedStringKey? = nil,
         tint: Color = Color.starlightGold) {
        self.init(icon: icon, title: title, subtitle: subtitle, tint: tint) { EmptyView() }
    }
}

// MARK: - Trailing pieces

struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.lavendar.opacity(0.45))
            .accessibilityHidden(true)
    }
}

struct StatusCapsule: View {
    enum Kind {
        case on
        case off
        case setUp
    }

    let kind: Kind

    var body: some View {
        switch kind {
        case .on:
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.restfulMint)
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.restfulMint.opacity(0.8), radius: 4)

                Text("On")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.restfulMint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.restfulMint.opacity(0.14)))
        case .off:
            Text("Off")
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .foregroundStyle(Color.lavendar.opacity(0.45))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.06)))
        case .setUp:
            Text("Set Up")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(Color.midnightNavy)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(NightGradient.gold))
                .shadow(color: Color.starlightGold.opacity(0.35), radius: 8, y: 2)
        }
    }
}

struct AccessPill: View {
    let isAllowed: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(isAllowed ? "Allowed" : "Allow")
                    .font(.system(.caption, design: .rounded, weight: .bold))

                Image(systemName: isAllowed ? "checkmark" : "arrow.up.forward.app")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(isAllowed ? Color.restfulMint : Color.midnightNavy)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isAllowed {
                    Capsule().fill(Color.restfulMint.opacity(0.14))
                } else {
                    Capsule().fill(NightGradient.gold)
                }
            }
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
