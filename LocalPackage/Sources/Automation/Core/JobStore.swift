//
//  JobStore.swift
//  LocalPackage
//

import Foundation

actor JobStore {

    private var jobs: [UUID: Job] = [:]

    private var continuations:
        [AsyncStream<Job>.Continuation] = []

    func events() -> AsyncStream<Job> {

        AsyncStream { continuation in
            continuations.append(continuation)
        }
    }

    func insert(_ job: Job) {

        jobs[job.id] = job

        publish(job)
    }

    func update(_ job: Job) {

        jobs[job.id] = job

        publish(job)
    }

    func all() -> [Job] {

        jobs.values.sorted {
            $0.createdAt > $1.createdAt
        }
    }

    func jobs(
        status: JobStatus
    ) -> [Job] {

        jobs.values.filter {
            $0.status == status
        }
    }

    func hasDuplicate(
        code: String,
        excluding id: UUID
    ) -> Bool {

        jobs.values.contains {

            $0.id != id &&
            $0.payload.codigo == code &&
            $0.status != .dupe
        }
    }

    private func publish(
        _ job: Job
    ) {

        continuations.forEach {
            $0.yield(job)
        }
    }
}
