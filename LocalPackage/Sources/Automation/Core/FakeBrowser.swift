//
//  FakeBrowser.swift
//  LocalPackage
//
//  Created by Juliana Miranda melo on 23/06/26.
//

@MainActor 
final class FakeBrowser:
    BrowserEngine {

    func open(
        url: String
    ) async throws {

        print(
            "Opening \(url)"
        )

        try await Task.sleep(
            for: .seconds(3)
        )
    }

    func click(
        selector: String
    ) async throws {}

    func fill(
        selector: String,
        value: String
    ) async throws {}
}
