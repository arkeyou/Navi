//
//  IAPManager.swift
//  DataSource
//

import Foundation
import StoreKit
import Observation

/// Represents an IAP Subscription Plan.
public struct IAPPlan: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let priceText: String
    public let periodText: String
    public let rawPrice: Decimal
    public let savingsBadge: String?
    public let product: Product?

    public init(
        id: String,
        title: String,
        priceText: String,
        periodText: String,
        rawPrice: Decimal,
        savingsBadge: String? = nil,
        product: Product? = nil
    ) {
        self.id = id
        self.title = title
        self.priceText = priceText
        self.periodText = periodText
        self.rawPrice = rawPrice
        self.savingsBadge = savingsBadge
        self.product = product
    }
}

@Observable @MainActor
public final class IAPManager {
    public static let shared = IAPManager()

    public static let monthlyProductID = "navipay01"
    public static let annualProductID = "navipay02"
    public static let allProductIDs: Set<String> = [monthlyProductID, annualProductID]

    public var availablePlans: [IAPPlan] = []
    public var selectedPlanID: String = IAPManager.annualProductID
    public var isLoading = false
    public var errorMessage: String? = nil
    public var purchaseSuccessMessage: String? = nil

    private nonisolated(unsafe) var transactionListener: Task<Void, Never>? = nil

    public init() {
        setupDefaultPlans()
        listenForTransactions()
        Task {
            await updateSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    /// Sets up default fallback plans matching app requirements (Plano Mensal navipay01, Plano Anual navipay02).
    public func setupDefaultPlans() {
        self.availablePlans = [
            IAPPlan(
                id: Self.monthlyProductID,
                title: "Plano Mensal",
                priceText: "R$ 99,90",
                periodText: "/ mês",
                rawPrice: 99.90,
                savingsBadge: nil
            ),
            IAPPlan(
                id: Self.annualProductID,
                title: "Plano Anual",
                priceText: "R$ 999,90",
                periodText: "/ ano",
                rawPrice: 999.90,
                savingsBadge: "16% off"
            )
        ]
    }

    /// Validates current entitlements against Apple's StoreKit 2 APIs.
    /// Updates `NaviQueueTracker.shared.isSubscribed` according to active unrevoked entitlements.
    public func updateSubscriptionStatus() async {
        var activeSubscribed = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Verify product ID is one of our subscription plans
                guard Self.allProductIDs.contains(transaction.productID) else { continue }

                // Check if transaction is revoked or expired
                if transaction.revocationDate == nil {
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > Date() {
                            activeSubscribed = true
                            break
                        }
                    } else {
                        // Non-expiring entitlement
                        activeSubscribed = true
                        break
                    }
                }
            } catch {
                print("Assinatura não verificada pela Apple: \(error.localizedDescription)")
            }
        }

        let isSub = activeSubscribed
        NaviQueueTracker.shared.isSubscribed = isSub
    }

    /// Fetches products from StoreKit if available.
    public func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: Self.allProductIDs)

            if !storeProducts.isEmpty {
                var plans: [IAPPlan] = []
                for product in storeProducts {
                    let isAnnual = product.id == Self.annualProductID
                    let periodText: String
                    if let period = product.subscription?.subscriptionPeriod {
                        periodText = formatSubscriptionPeriod(period)
                    } else {
                        periodText = isAnnual ? "/ ano" : "/ mês"
                    }

                    let plan = IAPPlan(
                        id: product.id,
                        title: product.displayName.isEmpty ? (isAnnual ? "Plano Anual" : "Plano Mensal") : product.displayName,
                        priceText: product.displayPrice,
                        periodText: periodText,
                        rawPrice: product.price,
                        savingsBadge: isAnnual ? "16% off" : nil,
                        product: product
                    )
                    plans.append(plan)
                }
                // Sort annual plan first
                plans.sort { $0.id == Self.annualProductID && $1.id != Self.annualProductID }
                self.availablePlans = plans
            }
        } catch {
            print("StoreKit fetch error: \(error.localizedDescription)")
            // Retain default plans on error/simulator mode
        }

        // Validate active subscriptions whenever fetching products
        await updateSubscriptionStatus()
    }

    /// Purchases the given plan using StoreKit 2.
    public func purchase(plan: IAPPlan) async -> Bool {
        isLoading = true
        errorMessage = nil
        purchaseSuccessMessage = nil
        defer { isLoading = false }

        if let product = plan.product {
            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    let transaction = try checkVerified(verification)
                    await transaction.finish()
                    await updateSubscriptionStatus()
                    purchaseSuccessMessage = "Assinatura realizada com sucesso! Aproveite envios ilimitados."
                    return true
                case .userCancelled:
                    return false
                case .pending:
                    purchaseSuccessMessage = "Compra pendente de aprovação."
                    return false
                @unknown default:
                    return false
                }
            } catch {
                errorMessage = "Erro na compra: \(error.localizedDescription)"
                return false
            }
        } else {
            // Simulated purchase for development/testing environments without StoreKit config file
            try? await Task.sleep(for: .seconds(1))
            NaviQueueTracker.shared.isSubscribed = true
            purchaseSuccessMessage = "Assinatura realizada com sucesso! (Modo de Demonstração)"
            return true
        }
    }

    /// Restores previous IAP purchases via AppStore.sync() and validates entitlements.
    public func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        purchaseSuccessMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()

            if NaviQueueTracker.shared.isSubscribed {
                purchaseSuccessMessage = "Sua assinatura foi restaurada com sucesso!"
                return true
            } else {
                errorMessage = "Nenhuma assinatura ativa foi encontrada para restaurar."
                return false
            }
        } catch {
            await updateSubscriptionStatus()
            if NaviQueueTracker.shared.isSubscribed {
                purchaseSuccessMessage = "Assinatura restaurada com sucesso."
                return true
            }
            errorMessage = "Falha ao restaurar: \(error.localizedDescription)"
            return false
        }
    }

    /// Listens for StoreKit transaction updates (renewals, revocations, external purchases).
    private func listenForTransactions() {
        transactionListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    guard let self = self else { return }
                    let transaction = try await self.checkVerified(result)
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                } catch {
                    print("Erro na atualização de transação StoreKit: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Verifies transaction signature from Apple StoreKit.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    private func formatSubscriptionPeriod(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return period.value == 1 ? "/ dia" : "/ \(period.value) dias"
        case .week:
            return period.value == 1 ? "/ semana" : "/ \(period.value) semanas"
        case .month:
            return period.value == 1 ? "/ mês" : "/ \(period.value) meses"
        case .year:
            return period.value == 1 ? "/ ano" : "/ \(period.value) anos"
        @unknown default:
            return ""
        }
    }
}

