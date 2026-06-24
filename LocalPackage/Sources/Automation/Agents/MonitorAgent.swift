//
//  MonitorAgent.swift
//  LocalPackage
//

import Foundation

@MainActor
final class MonitorAgent {

    private let store: JobStore
    private var task: Task<Void, Never>?

    init(
        store: JobStore
    ) {

        self.store = store
    }

    func start() {

        guard task == nil else { return }
        
        task = Task {

            //while !Task.isCancelled {
                print("MonitorAgent - monitorando mensagens")
                
                do {
                    try await Task.sleep(
                        for: .seconds(5)
                    )
                } catch {
                    //break
                }
                
                await scan()
            //}
        }
    }
    
    func stop() {
        task?.cancel()
        task = nil
    }

    private func scan() async {

        let apiItems = await fetchApiChanges()

        for item in apiItems {
            print("MonitorAgent - detectou codigo "+item.codigo)
            let job = Job(
                id: UUID(),
                payload: JobPayload (
                    codigo: item.codigo,
                    shopID: item.shopID,
                    itemID: item.itemID
                ),
                status: .added,
                createdAt: .now,
                updatedAt: .now
            )

            await store.insert(job)
        }
    }
    
    private func fetchApiChanges() async -> [JobPayload] {
        return [JobPayload (
            codigo: randomCodigo(),
            shopID: 0,
            itemID: 0
        ),JobPayload (
                codigo: randomCodigo(),
                shopID: 0,
                itemID: 0
        ),JobPayload (
            codigo: randomCodigo(),
            shopID: 0,
            itemID: 0
        ),JobPayload (
            codigo: randomCodigo(),
            shopID: 0,
            itemID: 0
        ),JobPayload (
            codigo: randomCodigo(),
            shopID: 0,
            itemID: 0
        ),JobPayload (
            codigo: randomCodigo(),
            shopID: 0,
            itemID: 0
        )]
    }
    
    private func randomCodigo() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        
        func randomBlock(length: Int) -> String {
            String((0..<length).compactMap{ _ in
                characters.randomElement()
            })
        }
        
        return "\(randomBlock(length: 3))-\(randomBlock(length: 3))-\(randomBlock(length: 3))"
    }
}
