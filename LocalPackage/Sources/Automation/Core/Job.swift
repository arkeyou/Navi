//
//  Job.swift
//  LocalPackage
//

import Foundation

struct Job: Identifiable, Codable {

    let id: UUID

    var payload: JobPayload

    var status: JobStatus

    var createdAt: Date

    var updatedAt: Date

    var errorMessage: String?
}
