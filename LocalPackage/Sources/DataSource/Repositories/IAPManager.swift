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

    public static let monthlyProductID = "com.navi.subscription.monthly"
    public static let annualProductID = "com.navi.subscription.annual"

    public var availablePlans: [IAPPlan] = []
    public var selectedPlanID: String = IAPManager.annualProductID
    public var isLoading = false
    public var errorMessage: String? = nil
    public var purchaseSuccessMessage: String? = nil

    private nonisolated(unsafe) var transactionListener: Task<Void, Never>? = nil

    public init() {
        setupDefaultPlans()
        listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    /// Sets up default fallback plans matching app requirements (Plano Mensal R$100, Plano Anual R$1000).
    public func setupDefaultPlans() {
        self.availablePlans = [
            IAPPlan(
                id: Self.monthlyProductID,
                title: "Plano Mensal",
                priceText: "R$ 100",
                periodText: "/ mês",
                rawPrice: 100.0,
                savingsBadge: nil
            ),
            IAPPlan(
                id: Self.annualProductID,
                title: "Plano Anual",
                priceText: "R$ 1.000",
                periodText: "/ ano",
                rawPrice: 1000.0,
                savingsBadge: "Economize 16%"
            )
        ]
    }

    /// Fetches products from StoreKit if available.
    public func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIDs: Set<String> = [Self.monthlyProductID, Self.annualProductID]
            let storeProducts = try await Product.products(for: productIDs)

            if !storeProducts.isEmpty {
                var plans: [IAPPlan] = []
                for product in storeProducts {
                    let isAnnual = product.id == Self.annualProductID
                    let plan = IAPPlan(
                        id: product.id,
                        title: isAnnual ? "Plano Anual" : "Plano Mensal",
                        priceText: product.displayPrice,
                        periodText: isAnnual ? "/ ano" : "/ mês",
                        rawPrice: product.price,
                        savingsBadge: isAnnual ? "Economize 16%" : nil,
                        product: product
                    )
                    plans.append(plan)
                }
                // Sort annual first
                plans.sort { $0.id == Self.annualProductID && $1.id != Self.annualProductID }
                self.availablePlans = plans
            }
        } catch {
            print("StoreKit fetch error: \(error.localizedDescription)")
            // Retain default plans on error/simulator mode
        }
    }

    /// Purchases the given plan.
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
                    NaviQueueTracker.shared.isSubscribed = true
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

    /// Restores previous IAP purchases.
    public func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        purchaseSuccessMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()

            var foundActive = false
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if transaction.revocationDate == nil {
                        foundActive = true
                        break
                    }
                }
            }

            if foundActive {
                NaviQueueTracker.shared.isSubscribed = true
                purchaseSuccessMessage = "Sua assinatura foi restaurada com sucesso!"
                return true
            } else {
                // If in demo/dev mode with local test subscription, retain or activate
                if NaviQueueTracker.shared.isSubscribed {
                    purchaseSuccessMessage = "Assinatura ativada previamente restaurada."
                    return true
                }
                errorMessage = "Nenhuma assinatura ativa foi encontrada para restaurar."
                return false
            }
        } catch {
            // Fallback for demo environment
            if NaviQueueTracker.shared.isSubscribed {
                purchaseSuccessMessage = "Assinatura restaurada com sucesso."
                return true
            }
            errorMessage = "Falha ao restaurar: \(error.localizedDescription)"
            return false
        }
    }

    private func listenForTransactions() {
        transactionListener = Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await MainActor.run {
                        NaviQueueTracker.shared.isSubscribed = true
                    }
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
