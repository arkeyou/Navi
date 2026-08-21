//
//  NaviConfig.swift
//  LocalPackage
//

struct NaviConfig: Decodable {
    var urlMonitor: String = ""
    var triggerMonitor: String = ""
    var urlFlow: String? = ""
    var urlAction: String = ""
    var script: String = ""
    var scriptVerify: String = ""
    var script2: String = ""
    var scriptVerify2: String = ""
    var urlSessionInfo: String?
    var urlSessionIdentifier: String?
}
