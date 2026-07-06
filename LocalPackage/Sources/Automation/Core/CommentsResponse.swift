//
//  CommentsResponse.swift
//  LocalPackage
//
//  Created by Juliana Miranda melo on 02/07/26.
//


import Foundation

struct CommentsResponse: Codable {
    let code: Int
    let msg: String?
    let data: CommentsData
}

struct CommentsData: Codable {
    let comments: [Comment]
    let timestamp: Int
}

struct Comment: Codable {
    let sessionId: Int
    let streamerId: Int
    let username: String
    let content: String
    let timestamp: Int
}