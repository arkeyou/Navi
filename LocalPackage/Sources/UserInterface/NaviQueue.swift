//
//  NaviQueue.swift
//  LocalPackage
//

import DataSource

actor NaviQueue<T> {
    private var items: [T] = []
    private var infos: [String] = []
    private var head = 0

    /// Enqueues an item if daily limit has not been reached or if user is subscribed.
    /// Returns true if item was enqueued successfully, false if daily limit was reached.
    @discardableResult
    func enqueue(_ item: T, info: String = "", isSubscribed: Bool = false) -> Bool {
        guard NaviQueueTracker.shared.canEnqueue(isSubscribed: isSubscribed) else {
            return false
        }
        
        let recorded = NaviQueueTracker.shared.recordEnqueue(isSubscribed: isSubscribed)
        guard recorded else {
            return false
        }

        items.append(item)
        infos.append(info)
        return true
    }

    func dequeue() -> (T?, String?) {
        guard head < items.count else { return (nil, nil) }

        let item = items[head]
        let info = infos[head]
        head += 1

        // Compactação periódica
        if head > 100 && head > items.count / 2 {
            items.removeFirst(head)
            infos.removeFirst(head)
            head = 0
        }

        return (item, info)
    }

    var isEmpty: Bool {
        head >= items.count
    }

    var count: Int {
        items.count - head
    }
    
    func list() {
        var i: Int = 0
        print("head: \(head)")
        items.forEach {
            i += 1
            print("\(i): \($0)")
        }
    }
}
