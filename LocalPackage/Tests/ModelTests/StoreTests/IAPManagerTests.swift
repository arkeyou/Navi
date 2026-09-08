//
//  IAPManagerTests.swift
//  ModelTests
//

import Foundation
import Testing
@testable import DataSource
@testable import Model

struct IAPManagerTests {
    @MainActor @Test
    func productIDsAreCorrectlyDefined() {
        #expect(IAPManager.monthlyProductID == "navipay01")
        #expect(IAPManager.annualProductID == "navipay02")
        #expect(IAPManager.allProductIDs.contains("navipay01"))
        #expect(IAPManager.allProductIDs.contains("navipay02"))
    }

    @MainActor @Test
    func defaultPlansMatchProductIDs() {
        let iapManager = IAPManager.shared
        iapManager.setupDefaultPlans()

        #expect(iapManager.availablePlans.count == 2)

        let monthlyPlan = iapManager.availablePlans.first(where: { $0.id == IAPManager.monthlyProductID })
        #expect(monthlyPlan != nil)
        #expect(monthlyPlan?.title == "Plano Mensal")
        #expect(monthlyPlan?.periodText == "/ mês")

        let annualPlan = iapManager.availablePlans.first(where: { $0.id == IAPManager.annualProductID })
        #expect(annualPlan != nil)
        #expect(annualPlan?.title == "Plano Anual")
        #expect(annualPlan?.periodText == "/ ano")
        #expect(annualPlan?.savingsBadge == "16% off")
    }

    @MainActor @Test
    func subscriptionStatusUpdatesNaviQueueTracker() async {
        let tracker = NaviQueueTracker.shared
        tracker.resetForTesting()
        #expect(tracker.isSubscribed == false)

        let iapManager = IAPManager.shared
        await iapManager.updateSubscriptionStatus()
        
        // Without real StoreKit entitlements in test, isSubscribed should evaluate to false
        #expect(tracker.isSubscribed == false)
    }
}
