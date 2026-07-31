//
//  File.swift
//  LocalPackage
//

import Foundation

public enum ActionEvent: Sendable {
    case enqueuePage(codigo: String, url: String, script: String, scriptVerify: String)
    case sendMsg(message: String)
    case openPage(url: String)
}
