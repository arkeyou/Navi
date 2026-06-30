//
//  File.swift
//  LocalPackage
//
//  Created by Juliana Miranda melo on 26/06/26.
//

import Foundation

public enum ActionEvent: Sendable {
    case openPage(codigo: String, url: String)
}
