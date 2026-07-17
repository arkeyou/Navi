//
//  ActionAgent.swift
//  LocalPackage
//


@MainActor
final class ActionAgent {
    
    private var URL_ACTION: String = ""

    private let store: JobStore
    private var task: Task<Void, any Error>?

    init(
        store: JobStore,
        urlAction: String
    ) {

        self.store = store
        self.URL_ACTION = urlAction
    }

    func start() {

        guard task == nil else { return }
        
        task = Task {

            let stream =
                await store.events()
            print("ActionAgent - quantidade de jobs: \(stream)")

            for await job in stream {
                if Task.isCancelled { break }

                guard job.status == .valid
                else { continue }

                print("ActionAgent - validando : \(job.payload.codigo) - \(type(of:job.payload.itemID)) - \(job.payload.shopID)")
                
                var current = job
                current.status = .ok
                current.payload.url = "\(URL_ACTION)\(current.payload.shopID).\(current.payload.itemID)"

                
                current.updatedAt = .now
                await store.update(current)
                //await execute(job)
            }
        }
    }
    
    func wait() async throws {
        try await task?.value
    }
    
    func stop() {
        task?.cancel()
        task = nil
    }

    /*private func execute(
        _ job: Job
    ) async {

        var current = job

        current.status = .isRunning
        current.updatedAt = .now

        await store.update(current)

        do {

            try await browser.open(
                url: current.payload.url
            )

            try await browser.click(
                selector: "#submit"
            )

            current.status = .ok
            current.updatedAt = .now

            await store.update(
                current
            )

        } catch {
            if error is CancellationError {
                return
            }

            current.status = .error
            current.errorMessage =
                error.localizedDescription

            current.updatedAt = .now

            await store.update(
                current
            )
        }
    }*/
    
}
