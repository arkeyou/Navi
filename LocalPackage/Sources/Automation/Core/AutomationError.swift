//
//  AutomationError.swift
//  LocalPackage
//
//  Created by Juliana Miranda melo on 16/07/26.
//


enum AutomationError: Error {
    case monitor(any Error)
    case flow(any Error)
    case action(any Error)
}
