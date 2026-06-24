//
//  BrowserEngine.swift
//  LocalPackage
//
//  Created by Juliana Miranda melo on 23/06/26.
//

@MainActor
protocol BrowserEngine {

    func open(
        url: String
    ) async throws

    func click(
        selector: String
    ) async throws

    func fill(
        selector: String,
        value: String
    ) async throws
}
