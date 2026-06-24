//
//  FlowAgent.swift
//  LocalPackage
//
import Foundation

@MainActor
final class FlowAgent {

    private let store: JobStore
    private var task: Task<Void, Never>?

    init(
        store: JobStore
    ) {
        self.store = store
    }

    func start() {
        
        guard task == nil else { return }
        
        task = Task {

            let stream =
                await store.events()
            print("FlowAgent - quantidade de jobs: \(stream)")
            for await job in stream {
                if Task.isCancelled { break }

                guard job.status == .added
                else { continue }

                await validate(job)
            }
        }
    }
    
    func stop() {
        task?.cancel()
        task = nil
    }

    private func validate(
        _ job: Job
    ) async {
        var current = job

        print("FlowAgent - validando: \(current.payload.codigo)")

        current.status = .isValidating
        current.updatedAt = .now

        await store.update(current)

        let isDuplicate =
            await store.hasDuplicate(
                code: current.payload.codigo,
                excluding: current.id
            )

        if isDuplicate {
            print("FlowAgent - duplicado: \(current.payload.codigo)")

            current.status = .dupe
            current.updatedAt = .now

            await store.update(current)

            return
        }

        // outras validações

        do {
            try await Task.sleep(
                for: .seconds(1)
            )
        } catch {
            return
        }
        print("FlowAgent - processado: \(current.payload.codigo)")

        current.status = .valid
        current.updatedAt = .now
        current.payload.itemID = 123456
        current.payload.shopID = 123456

        await store.update(current)
    }
}
