//
//  ActionAgent.swift
//  LocalPackage
//


@MainActor
final class ActionAgent {

    private let store: JobStore
    private var task: Task<Void, Never>?
    
    private let browser:
        BrowserEngine

    init(
        store: JobStore,
        browser: BrowserEngine
    ) {

        self.store = store
        self.browser = browser
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

                print("ActionAgent - abrindo no browser: \(job.payload.codigo)")

                //await execute(job)
            }
        }
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
