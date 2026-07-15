//
//  NaviConfig.swift
//  LocalPackage
//

struct NaviConfig: Decodable {
    var urlMonitor: String = ""
    var triggerMonitor: String = ""
    var urlFlow: String = ""
    var urlAction: String = ""
    var script: String = ""
    var scriptVerify: String = ""
    var urlSessionInfo: String?
}
