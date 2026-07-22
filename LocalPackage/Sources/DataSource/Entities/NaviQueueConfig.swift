//
//  NaviQueueConfig.swift
//  DataSource
//

import Foundation

/// Internal application configuration for NaviQueue.
public struct NaviQueueConfig: Sendable {
    /// Maximum number of IDs added to `NaviQueue` per day for free users.
    /// Parameterized and fixed in internal application settings (requires new deploy to change).
    public static let dailyLimit: Int = 2
}
