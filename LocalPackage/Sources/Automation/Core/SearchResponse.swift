//
//  SearchResponse.swift
//  LocalPackage
//

struct SearchResponse: Codable {
    let bffMeta: String?
    let error: String?
    let debugMsg: String?
    let directSearchResult: DirectSearchResult
    let searchInfo: String?
    
    enum CodingKeys: String, CodingKey {
        case bffMeta = "bff_meta"
        case error
        case debugMsg = "debug_msg"
        case directSearchResult = "direct_search_result"
        case searchInfo = "search_info"
    }
}

struct DirectSearchResult: Codable {
    let resultType: Int
    let item: Item
    
    enum CodingKeys: String, CodingKey {
        case resultType = "result_type"
        case item
    }
}

struct Item: Codable {
    let itemID: Int
    let shopID: Int
    
    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case shopID = "shop_id"
    }
}

struct SearchInfo : Codable {
    let abSign: [String]
    
    enum CodingKeys: String, CodingKey {
        case abSign = "ab_sign"
    }
}
