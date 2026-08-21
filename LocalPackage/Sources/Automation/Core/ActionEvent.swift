//
//  File.swift
//  LocalPackage
//

import Foundation

public enum ActionEvent: Sendable {
    case enqueuePage(codigo: String, url: String, username: String, script: String, scriptVerify: String, script2: String, scriptVerify2: String)
    case sendMsg(message: String, stop: Bool = true)
    case openPage(url: String)
}
