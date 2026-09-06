//
//  NaviConfig.swift
//  LocalPackage
//

struct NaviConfig: Decodable {
    init() {}
    
    //Monitor
    var urlMonitor: String = ""
    var triggerMonitor: String = ""
    
    //Flow
    var urlFlow: String? = ""
    
    //Action
    var urlAction: String = ""
    
    //Browser
    var mainVerify: AutomationScript = AutomationScript()
    var mainAction: AutomationScript = AutomationScript()
    var secondaryVerify: AutomationScript? = AutomationScript()
    var secondaryAction: AutomationScript? = AutomationScript()
    
    /*var script: String = ""
    var scriptVerify: String = ""
    var script2: String = ""
    var scriptVerify2: String = ""*/
    
    //Core
    var urlSessionInfo: String?
    var urlSessionIdentifier: String?

}

struct AutomationScript: Decodable {
    init() {}
    
    var type: String = ""
    var message: String?
    var selector: String?
}
