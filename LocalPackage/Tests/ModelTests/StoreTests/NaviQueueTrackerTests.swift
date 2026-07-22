//
//  NaviQueueTrackerTests.swift
//  ModelTests
//

import Foundation
import Testing
@testable import DataSource
@testable import Model

struct NaviQueueTrackerTests {
    @MainActor @Test
    func dailyLimitParameterIsFixedAt10() {
        #expect(NaviQueueConfig.dailyLimit == 10)
    }

    @MainActor @Test
    func trackerEnforces10ItemsDailyLimitForFreeUsers() {
        let tracker = NaviQueueTracker.shared
        tracker.resetForTesting()
        
        #expect(!tracker.isLimitReached)
        #expect(tracker.remainingToday() == 10)

        // Record 10 items
        for i in 1...10 {
            #expect(tracker.canEnqueue())
            let result = tracker.recordEnqueue()
            #expect(result == true)
            #expect(tracker.countToday == i)
        }

        // 11th item should be rejected
        #expect(tracker.isLimitReached)
        #expect(!tracker.canEnqueue())
        #expect(tracker.remainingToday() == 0)
        
        let 11thResult = tracker.recordEnqueue()
        #expect(11thResult == false)
        #expect(tracker.countToday == 10)
    }

    @MainActor @Test
    func trackerAllowsUnlimitedItemsWhenSubscribed() {
        let tracker = NaviQueueTracker.shared
        tracker.resetForTesting()
        tracker.isSubscribed = true

        #expect(tracker.isSubscribed == true)
        #expect(!tracker.isLimitReached)

        for _ in 1...15 {
            #expect(tracker.canEnqueue())
            #expect(tracker.recordEnqueue() == true)
        }
    }
}
