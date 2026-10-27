//
//  ProManager.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-23.
//

import Foundation
import StoreKit
import SwiftUI
import UIKit

// MARK: - ProManager

@Observable
@MainActor
final class ProManager {
    static let shared = ProManager()

    static let monthlyID = "snoozly_pro_monthly"
    static let yearlyID = "snoozly_pro_yearly"
    static let productIDs = [monthlyID, yearlyID]

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL: URL? = nil

    enum LoadFailure: Equatable {
        case noProducts
        case error(String)
    }

    enum PurchaseOutcome {
        case success
        case cancelled
        case pending
        case failed
    }

    private(set) var isPro: Bool
    private(set) var products: [Product] = []
    private(set) var isLoadingProducts = false
    private(set) var loadFailure: LoadFailure?
    private(set) var missingProductIDs: [String] = []
    private(set) var isRestoring = false
    private(set) var hasResolvedStatus = false
    private(set) var isEligibleForTrial = false
    private(set) var renewalDate: Date?
    private(set) var willAutoRenew = true
    private(set) var activeProductID: String?
    private(set) var activeTransactionID: UInt64?
    private(set) var storeEnvironment: String?
    var errorMessage: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var activeTask: Task<Void, Never>?
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    private init() {
        isPro = UserDefaults.standard.bool(forKey: AppStorageKey.isPro)
        startListeningForTransactions()
        startListeningForForeground()
        Task {
            await refresh()
        }
    }

    var didFailToLoadProducts: Bool {
        loadFailure != nil
    }

    // MARK: - Products

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyID }
    }

    var yearlySavingsPercent: Int? {
        guard let monthly = monthlyProduct, let yearly = yearlyProduct else { return nil }
        let fullYear = monthly.price * 12
        guard fullYear > 0 else { return nil }
        let saved = (fullYear - yearly.price) / fullYear
        let percent = Int((NSDecimalNumber(decimal: saved).doubleValue * 100).rounded())
        return percent > 0 ? percent : nil
    }

    var yearlyPricePerMonth: String? {
        guard let yearly = yearlyProduct else { return nil }
        return (yearly.price / 12).formatted(yearly.priceFormatStyle)
    }

    var yearlyTrialText: String? {
        guard isEligibleForTrial,
              let offer = yearlyProduct?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        return Self.periodText(offer.period)
    }

    var yearlyTrialLength: String? {
        guard isEligibleForTrial,
              let offer = yearlyProduct?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let unit: String
        switch offer.period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "day"
        }
        return offer.period.value == 1 ? "1 \(unit)" : "\(offer.period.value) \(unit)s"
    }

    private static func periodText(_ period: Product.SubscriptionPeriod) -> String {
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "day"
        }
        return "\(period.value)-\(unit)"
    }

    // MARK: - Refresh

    func refresh() async {
        await loadProducts()
        await updatePurchasedStatus()
    }

    func loadProducts() async {
        if let loadTask {
            await loadTask.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoad()
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        var lastError: Error?

        for attempt in 0..<3 {
            do {
                let loaded = try await Product.products(for: Self.productIDs)
                products = loaded.sorted { $0.price < $1.price }
                missingProductIDs = Self.productIDs.filter { id in
                    !loaded.contains { $0.id == id }
                }
                loadFailure = loaded.isEmpty ? .noProducts : nil
                lastError = nil
                break
            } catch {
                lastError = error
                guard attempt < 2 else { break }
                try? await Task.sleep(for: .seconds(attempt + 1))
            }
        }

        if let lastError {
            loadFailure = .error(Self.friendlyMessage(for: lastError))
        }

        #if DEBUG
        if loadFailure != nil {
            await resolveStoreEnvironment()
        }
        #endif

        if let subscription = yearlyProduct?.subscription, subscription.introductoryOffer != nil {
            isEligibleForTrial = await subscription.isEligibleForIntroOffer
        } else {
            isEligibleForTrial = false
        }
    }

    #if DEBUG
    private func resolveStoreEnvironment() async {
        guard let result = try? await AppTransaction.shared else {
            storeEnvironment = "unknown"
            return
        }

        switch result {
        case .verified(let transaction):
            storeEnvironment = String(describing: transaction.environment)
        case .unverified(let transaction, _):
            storeEnvironment = String(describing: transaction.environment)
        }
    }
    #endif

    func refreshIfNeeded() async {
        if products.isEmpty || loadFailure != nil {
            await loadProducts()
        }
        await updatePurchasedStatus()
    }

    // MARK: - Errors

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let storeError = error as? StoreKitError, case .userCancelled = storeError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private static func friendlyMessage(for error: Error) -> String {
        if let storeError = error as? StoreKitError {
            switch storeError {
            case .networkError:
                return "Snoozly couldn't reach the App Store. Check your connection and try again."
            case .notAvailableInStorefront:
                return "Snoozly Pro isn't available in your App Store region yet."
            case .notEntitled:
                return "This Apple Account can't buy Snoozly Pro right now."
            default:
                break
            }
        }

        if isCancellation(error) {
            return "The App Store request was interrupted. Tap Try Again."
        }

        return "The App Store didn't respond. Try again in a moment."
    }

    var loadDiagnostics: String? {
        #if DEBUG
        switch loadFailure {
        case .noProducts:
            let environment = storeEnvironment.map { " [store: \($0)]" } ?? ""
            return "Got 0 of \(Self.productIDs.count) products\(environment). If the store isn't Xcode, the scheme's StoreKit configuration isn't active: Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration. If it is, the IDs in Products.storekit don't match \(Self.productIDs.joined(separator: ", "))."
        case .error(let message):
            return message
        case nil:
            return missingProductIDs.isEmpty ? nil : "Missing: \(missingProductIDs.joined(separator: ", "))"
        }
        #else
        return nil
        #endif
    }

    // MARK: - Purchase

    func handle(_ result: Product.PurchaseResult) async -> PurchaseOutcome {
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                await updatePurchasedStatus()
                errorMessage = nil
                return .success
            case .unverified:
                errorMessage = "We couldn't verify that purchase. Please try again or restore purchases."
                return .failed
            }
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .failed
        }
    }

    func restorePurchases() async {
        guard !isRestoring else { return }
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await updatePurchasedStatus()
            if !isPro {
                errorMessage = "No active Snoozly Pro subscription was found for this Apple Account."
            }
        } catch {
            guard !Self.isCancellation(error) else { return }
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    // MARK: - Entitlements

    private func startListeningForTransactions() {
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.updatePurchasedStatus()
            }
        }
    }

    private func startListeningForForeground() {
        activeTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                await self?.refreshIfNeeded()
            }
        }
    }

    func updatePurchasedStatus() async {
        var current: StoreKit.Transaction?

        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < .now { continue }
            current = transaction
            break
        }

        if let current {
            activeProductID = current.productID
            activeTransactionID = current.id
            renewalDate = current.expirationDate
            willAutoRenew = await autoRenewState(for: current)
        } else {
            activeProductID = nil
            activeTransactionID = nil
            renewalDate = nil
            willAutoRenew = true
        }

        isPro = current != nil
        UserDefaults.standard.set(isPro, forKey: AppStorageKey.isPro)
        hasResolvedStatus = true
    }

    private func autoRenewState(for transaction: StoreKit.Transaction) async -> Bool {
        guard let subscription = products.first(where: { $0.id == transaction.productID })?.subscription,
              let statuses = try? await subscription.status else { return true }

        for status in statuses {
            if case .verified(let info) = status.renewalInfo {
                return info.willAutoRenew
            }
        }
        return true
    }

    func waitUntilResolved(timeout: Duration = .seconds(3)) async {
        let deadline = ContinuousClock.now + timeout
        while !hasResolvedStatus && ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
