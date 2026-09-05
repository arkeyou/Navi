//
//  NaviConfig.swift
//  LocalPackage
//

struct NaviConfig: Decodable {
    //Monitor
    var urlMonitor: String = ""
    var triggerMonitor: String = ""
    //Flow
    var urlFlow: String? = ""
    //Action
    var urlAction: String = ""
    //Browser
    var script: String = ""
    var scriptVerify: String = ""
    var script2: String = ""
    var scriptVerify2: String = ""
    //Core
    var urlSessionInfo: String?
    var urlSessionIdentifier: String?
}
