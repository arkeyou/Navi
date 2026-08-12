//
//  LiveHistoryResponse.swift
//  LocalPackage

import Foundation

struct LiveHistoryResponse: Codable {
    let code: Int
    let msg: String?
    let data: LiveHistoryData
}

struct LiveHistoryData: Codable {
    let page: Int
    let pageSize: Int
    let total: Int
    let list: [LiveSession]
    let totalPage: Int
    let rowBounds: RowBounds
}

struct LiveSession: Codable {
    let sessionId: Int64
    let title: String
    let coverImage: String
    let startTime: Int64
    let duration: Int64
    let status: Int

    let conversionRate: Double?
    let views: Int?
    let likes: Int?
    let followersGrowth: Int?
    let productClicks: Int?
    let viewers: Int?
    let peakViewers: Int?
    let avgViewsDuration: Double?
    let comments: Int?
    let atc: Int?

    let placedOrders: Int?
    let placedSales: Double?
    let confirmedOrders: Int?
    let confirmedSales: Double?
}

struct RowBounds: Codable {
    let offset: Int
    let limit: Int
}

struct LiveHistoryErrorResponse: Codable, Error {
    let errcode: Int
    let message: String
}
