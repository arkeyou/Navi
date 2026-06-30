//
//  NaviQueue.swift
//  LocalPackage
//


actor NaviQueue<T> {
    private var items: [T] = []
    private var head = 0

    func enqueue(_ item: T) {
        items.append(item)
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
