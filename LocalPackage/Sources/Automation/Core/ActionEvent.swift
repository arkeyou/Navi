//
//  File.swift
//  LocalPackage
//

import Foundation

public enum ActionEvent: Sendable {
    case openPage(codigo: String, url: String, script: String)
}
