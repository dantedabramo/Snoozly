//
//  ProSheetView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-23.
//

import SwiftUI
import StoreKit

// MARK: - ProSheetView

struct ProSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchase
    @State private var proManager = ProManager.shared
    @State private var selectedPlan: Plan = .yearly
    @State private var isPurchasing = false
    @State private var notice: String?
    @State private var showManageSubscriptions = false

    enum Plan: String, Identifiable {
        case monthly
        case yearly

        var id: String { rawValue }

        var productID: String {
            switch self {
            case .monthly: ProManager.monthlyID
            case .yearly: ProManager.yearlyID
            }
        }
    }

    private var selectedProduct: Product? {
        selectedPlan == .yearly ? proManager.yearlyProduct : proManager.monthlyProduct
    }

    private var hasTrialOnSelection: Bool {
        selectedPlan == .yearly && proManager.yearlyTrialText != nil
    }

    private var sheetDetents: Set<PresentationDetent> {
        proManager.isPro ? [.fraction(0.7)] : [.large]
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NightBackground(mood: .calm)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 14) {
                        hero

                        if proManager.isPro {
                            activeCard
                        } else {
                            plansSection
                            featuresCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)

                if !proManager.isPro {
                    footer
                }
            }

            closeButton
        }
        .task {
            if proManager.products.isEmpty {
                await proManager.loadProducts()
            }
        }
        .presentationDetents(sheetDetents)
        .presentationDragIndicator(.visible)
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .sensoryFeedback(.success, trigger: proManager.isPro) { old, new in !old && new }
        .interactiveDismissDisabled(isPurchasing)
    }

    // MARK: - Close

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.lavendar)
                .frame(width: 36, height: 36)
                .nightCard(cornerRadius: 18, blurs: false)
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Close")
        .padding(.top, 14)
        .padding(.trailing, 16)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 6) {
            ZStack {
                GlowOrb(color: Color.dreamPurple, opacity: 0.55, diameter: 130)

                SleepyCreatureView(showStars: true)
                    .frame(width: 80, height: 80)
            }
            .frame(height: 100)
            .padding(.top, 10)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(proManager.isPro ? "You're on Snoozly" : "Sleep better with Snoozly")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    proBadge
                }

                Text(proManager.isPro
                     ? "Thanks for supporting Snoozly. Every Pro feature is unlocked."
                     : "Look further ahead, spot what shapes your nights, and keep every check-in.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.midnightNavy)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.starlightGold))
    }

    // MARK: - Features

    private var featuresCard: some View {
        VStack(spacing: 12) {
            featureRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "14-day and 1-month trends",
                subtitle: "See how your sleep score moves over weeks, not just days."
            )
            featureRow(
                icon: "calendar.badge.clock",
                title: "Upcoming nights",
                subtitle: "Look two full weeks ahead at your bedtimes."
            )
            featureRow(
                icon: "clock.arrow.circlepath",
                title: "Full check-in history",
                subtitle: "Open every past check-in, not just the latest one."
            )
            featureRow(
                icon: "sparkles",
                title: "What shapes your sleep",
                subtitle: "Find out which habits raise or lower your score."
            )
        }
        .padding(14)
        .nightCard(cornerRadius: 24)
    }

    private func featureRow(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.starlightGold)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.midnightNavy.opacity(0.65)))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Plans

    @ViewBuilder
    private var plansSection: some View {
        if proManager.isLoadingProducts && proManager.products.isEmpty {
            VStack(spacing: 12) {
                SwiftUI.ProgressView()
                    .tint(Color.lavendar)

                Text("Loading plans…")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.75))
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else if proManager.products.isEmpty {
            unavailableCard
        } else {
            VStack(spacing: 10) {
                if let yearly = proManager.yearlyProduct {
                    planCard(
                        plan: .yearly,
                        title: "Yearly",
                        price: yearly.displayPrice,
                        detail: yearlyDetail,
                        badge: proManager.yearlySavingsPercent.map { "SAVE \($0)%" }
                    )
                }

                if let monthly = proManager.monthlyProduct {
                    planCard(
                        plan: .monthly,
                        title: "Monthly",
                        price: monthly.displayPrice,
                        detail: "Billed every month",
                        badge: nil
                    )
                }
            }
        }
    }

    private var yearlyDetail: String {
        if let perMonth = proManager.yearlyPricePerMonth {
            return "Just \(perMonth) a month, billed yearly"
        }
        return "Billed every year"
    }

    private var unavailableCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.starlightGold)

            Text("Plans aren't available right now")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(unavailableMessage)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.lavendar.opacity(0.8))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let diagnostics = proManager.loadDiagnostics {
                Text(diagnostics)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.starlightGold.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task {
                    await proManager.loadProducts()
                }
            } label: {
                Text("Try Again")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.midnightNavy)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.lavendar))
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .nightCard(cornerRadius: 24)
    }

    private var unavailableMessage: String {
        switch proManager.loadFailure {
        case .error(let message):
            return message
        default:
            return "The App Store didn't return the Snoozly Pro plans. Give it a moment, then try again."
        }
    }

    private func planCard(
        plan: Plan,
        title: LocalizedStringKey,
        price: String,
        detail: String,
        badge: String?
    ) -> some View {
        let isSelected = selectedPlan == plan

        return Button {
            withAnimation(.snappy) {
                selectedPlan = plan
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.starlightGold : Color.lavendar.opacity(0.45))
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.midnightNavy)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.starlightGold))
                        }
                    }

                    Text(detail)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.lavendar.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(price)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color.dreamPurple.opacity(0.28) : Color.white.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.starlightGold : Color.white.opacity(0.12),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .sensoryFeedback(.selection, trigger: selectedPlan)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Active Subscription

    private var activeCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                activeRow(title: "Plan", value: activePlanName)

                if let renewal = proManager.renewalDate {
                    Divider().overlay(Color.white.opacity(0.1))

                    activeRow(
                        title: proManager.willAutoRenew ? "Renews" : "Ends",
                        value: renewal.formatted(date: .abbreviated, time: .omitted)
                    )
                }
            }
            .padding(18)
            .nightCard(cornerRadius: 24)

            Button {
                showManageSubscriptions = true
            } label: {
                Text("Manage Subscription")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.midnightNavy)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Capsule().fill(Color.lavendar))
            }
            .buttonStyle(PressScaleButtonStyle())

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.lavendar.opacity(0.85))
            }
        }
    }

    private var activePlanName: String {
        switch proManager.activeProductID {
        case ProManager.yearlyID: "Snoozly Pro Yearly"
        case ProManager.monthlyID: "Snoozly Pro Monthly"
        default: "Snoozly Pro"
        }
    }

    private func activeRow(title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.lavendar.opacity(0.8))

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            if let notice {
                Text(notice)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.starlightGold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }

            OnboardingForwardButton(
                title: ctaTitle,
                systemImage: nil,
                isEnabled: selectedProduct != nil && !proManager.isRestoring,
                isBusy: isPurchasing
            ) {
                startPurchase()
            }

            Text(finePrint)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.lavendar.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            linksRow
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background {
            LinearGradient(
                colors: [Color.midnightNavy.opacity(0), Color.midnightNavy.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .animation(.snappy, value: notice)
    }

    private var linksRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                restoreButton
                linkDot
                LegalLink(title: "Terms of Use", url: ProManager.termsURL)
                linkDot
                LegalLink(title: "Privacy Policy", url: ProManager.privacyURL)
            }

            VStack(spacing: 2) {
                restoreButton

                HStack(spacing: 12) {
                    LegalLink(title: "Terms of Use", url: ProManager.termsURL)
                    linkDot
                    LegalLink(title: "Privacy Policy", url: ProManager.privacyURL)
                }
            }
        }
        .font(.system(.caption, design: .rounded, weight: .semibold))
        .foregroundStyle(Color.lavendar.opacity(0.8))
        .frame(minHeight: 36)
    }

    private var linkDot: some View {
        Circle()
            .fill(Color.lavendar.opacity(0.35))
            .frame(width: 3, height: 3)
            .accessibilityHidden(true)
    }

    private var restoreButton: some View {
        Button {
            Task {
                notice = nil
                notice = await proManager.restorePurchases()
                if proManager.isPro {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 6) {
                if proManager.isRestoring {
                    SwiftUI.ProgressView()
                        .controlSize(.mini)
                        .tint(Color.lavendar)
                }

                Text("Restore Purchases")
            }
            .frame(minHeight: 32)
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing || proManager.isRestoring)
    }

    private var ctaTitle: LocalizedStringKey {
        if hasTrialOnSelection, let trial = proManager.yearlyTrialText {
            return "Start \(trial) Free Trial"
        }
        return "Continue"
    }

    private var finePrint: String {
        guard let product = selectedProduct else {
            return "Subscriptions renew automatically until cancelled."
        }

        let period = selectedPlan == .yearly ? "year" : "month"
        if hasTrialOnSelection, let length = proManager.yearlyTrialLength {
            return "Free for \(length), then \(product.displayPrice) per \(period). Renews automatically. Cancel anytime in your Apple Account settings."
        }
        return "\(product.displayPrice) per \(period). Renews automatically. Cancel anytime in your Apple Account settings."
    }

    // MARK: - Purchase

    private func startPurchase() {
        guard let product = selectedProduct, !isPurchasing else { return }

        Task {
            isPurchasing = true
            notice = nil

            do {
                let result = try await purchase(product)
                let outcome = await proManager.handle(result)
                switch outcome {
                case .success:
                    isPurchasing = false
                    dismiss()
                    return
                case .pending:
                    notice = "Your purchase is waiting for approval. Snoozly Pro unlocks as soon as it's approved."
                case .unverified:
                    notice = "We couldn't verify that purchase. Please try again or restore purchases."
                case .failed:
                    notice = "That purchase didn't go through. Please try again."
                case .cancelled:
                    break
                }
            } catch {
                notice = ProManager.purchaseMessage(for: error)
            }

            isPurchasing = false
        }
    }
}

#Preview {
    ProSheetView()
}
