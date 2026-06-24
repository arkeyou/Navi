//
//  JobStatus.swift
//  LocalPackage
//


enum JobStatus: String, Codable {

    // MonitorAgent
    case added

    // FlowAgent
    case isValidating
    case dupe
    case valid

    // ActionAgent
    case isRunning
    case ok
    case error
}
