//
//  JobPayload.swift
//  LocalPackage
//


struct JobPayload: Codable {

    let codigo: String
    var param1: Int64 //shopID
    var param2: Int64 //itemID
    var url: String
    
}
