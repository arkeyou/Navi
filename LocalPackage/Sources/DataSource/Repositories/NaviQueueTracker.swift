//
//  NaviQueueTracker.swift
//  DataSource
//

import Foundation

/// Repository for tracking daily enqueue limits and subscription status.
public final class NaviQueueTracker: @unchecked Sendable {
    public static let shared = NaviQueueTracker()

    private let userDefaults: UserDefaults
    private let dateKey = "Navi_DailyQueue_Date"
    private let countKey = "Navi_DailyQueue_Count"
    private let subscribedKey = "Navi_IsSubscribed"
    private let lock = NSLock()

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    /// Resets the daily count if today is a new calendar day compared to last recorded date.
    public func resetIfNewDay() {
        lock.lock()
        defer { lock.unlock() }

        let today = todayString()
        let savedDate = userDefaults.string(forKey: dateKey) ?? ""
        if savedDate != today {
            userDefaults.set(today, forKey: dateKey)
            userDefaults.set(0, forKey: countKey)
        }
    }
    
    @discardableResult
    public func resetEnqueueToday(isSubscribed: Bool = false) -> Bool {
        if isSubscribed || self.isSubscribed { return true }
        lock.lock()
        defer { lock.unlock() }

        userDefaults.set(0, forKey: countKey)
        return true
    }

    /// Returns the number of IDs added to NaviQueue today.
    public var countToday: Int {
        resetIfNewDay()
        lock.lock()
        defer { lock.unlock() }
        return userDefaults.integer(forKey: countKey)
    }

    /// Indicates whether the limit has been reached for today and user is not subscribed.
    public var isLimitReached: Bool {
        if isSubscribed { return false }
        return countToday >= NaviQueueConfig.dailyLimit
    }

    /// Subscription status (true if active IAP subscription is present).
    public var isSubscribed: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return userDefaults.bool(forKey: subscribedKey)
        }
        set {
            lock.lock()
            userDefaults.set(newValue, forKey: subscribedKey)
            lock.unlock()
        }
    }

    /// Checks if a new ID can be enqueued.
    public func canEnqueue(isSubscribed: Bool = false) -> Bool {
        if isSubscribed || self.isSubscribed { return true }
        resetIfNewDay()
        lock.lock()
        defer { lock.unlock() }
        return userDefaults.integer(forKey: countKey) < NaviQueueConfig.dailyLimit
    }

    /// Records an enqueued item if limit has not been reached. Returns true if successfully recorded.
    @discardableResult
    public func recordEnqueue(isSubscribed: Bool = false) -> Bool {
        if isSubscribed || self.isSubscribed { return true }
        resetIfNewDay()
        lock.lock()
        defer { lock.unlock() }

        let current = userDefaults.integer(forKey: countKey)
        if current >= NaviQueueConfig.dailyLimit {
            return false
        }
        userDefaults.set(current + 1, forKey: countKey)
        return true
    }

    /// Returns remaining allowed enqueues for today.
    public func remainingToday(isSubscribed: Bool = false) -> Int {
        if isSubscribed || self.isSubscribed { return Int.max }
        resetIfNewDay()
        lock.lock()
        defer { lock.unlock() }
        let current = userDefaults.integer(forKey: countKey)
        return max(0, NaviQueueConfig.dailyLimit - current)
    }

    /// Manually reset count for testing / debugging.
    public func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        userDefaults.set(todayString(), forKey: dateKey)
        userDefaults.set(0, forKey: countKey)
        userDefaults.set(false, forKey: subscribedKey)
    }
}
