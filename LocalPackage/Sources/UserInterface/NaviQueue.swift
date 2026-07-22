//
//  NaviQueue.swift
//  LocalPackage
//

import DataSource

actor NaviQueue<T> {
    private var items: [T] = []
    private var head = 0

    /// Enqueues an item if daily limit has not been reached or if user is subscribed.
    /// Returns true if item was enqueued successfully, false if daily limit was reached.
    @discardableResult
    func enqueue(_ item: T, isSubscribed: Bool = false) -> Bool {
        guard NaviQueueTracker.shared.canEnqueue(isSubscribed: isSubscribed) else {
            return false
        }
        
        let recorded = NaviQueueTracker.shared.recordEnqueue(isSubscribed: isSubscribed)
        guard recorded else {
            return false
        }

        items.append(item)
        return true
    }

    func dequeue() -> T? {
        guard head < items.count else { return nil }

        let item = items[head]
        head += 1

        // Compactação periódica
        if head > 100 && head > items.count / 2 {
            items.removeFirst(head)
            head = 0
        }

        return item
    }

    var isEmpty: Bool {
        head >= items.count
    }

    var count: Int {
        items.count - head
    }
}
