//
//  MonitorAgent.swift
//  LocalPackage
//

import Foundation

@MainActor
final class MonitorAgent {

    private var URL_MONITOR: String
    private var SESSION_ID: String
    private var INTERVAL: Int = 5
    private var TRIGGER = /[a-zA-Z]{3}-[a-zA-Z]{3}-[a-zA-Z]{3}+/
    private let MONITOR_INTERVAL = Duration.seconds(4)
    
    private let store: JobStore
    private var task: Task<Void, Never>?
    private let cookies: String

    init(
        store: JobStore,
        urlMonitor: String,
        sessionId: String,
        cookieList: String
    ) {

        self.store = store
        self.URL_MONITOR = urlMonitor
        self.SESSION_ID = sessionId
        self.cookies = cookieList
    }

    func start() {

        guard task == nil else { return }
        
        task = Task {

            while !Task.isCancelled {
                print("MonitorAgent - monitorando mensagens")
                
                do {
                    try await Task.sleep(
                        for: MONITOR_INTERVAL
                    )
                } catch {
                    //break
                }
                do {
                    try await scan()
                } catch {
                    
                }
            }
        }
    }
    
    func stop() {
        task?.cancel()
        task = nil
    }

    private func scan() async throws {

        let apiItems = try await fetchApiChanges()
        //let apiItems = try await fetchApiChangesMock()

        for item in apiItems {
            print("MonitorAgent - detectou codigo "+item.codigo)
            let job = Job(
                id: UUID(),
                payload: JobPayload (
                    codigo: item.codigo,
                    shopID: item.shopID,
                    itemID: item.itemID,
                    url: item.url
                ),
                status: .added,
                createdAt: .now,
                updatedAt: .now
            )

            await store.insert(job)
        }
    }
    
    private func fetchApiChanges() async throws -> [JobPayload] {
        
        let urlFormatada = String(format: URL_MONITOR, arguments: [SESSION_ID])
        guard let url = URL(string: urlFormatada) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        //print(cookies)
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        print(String(data: data, encoding: .utf8) ?? "Nao conseguiu ler o body")
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        
        do {
            let commentsResult = try JSONDecoder().decode(CommentsResponse.self, from: data)
            
            var listaJobPayload: [JobPayload] = []
            for item in commentsResult.data.comments {
                let codigos = item.content.matches(of: TRIGGER).map { String($0.output) }
                
                for codigo in codigos {
                    listaJobPayload.append(JobPayload (codigo: codigo, shopID: 0, itemID: 0, url: ""))
                }
            }
            return listaJobPayload
        } catch {
            print(error.localizedDescription)
            throw error
        }
    }
    
    private func fetchApiChangesMock() async throws -> [JobPayload] {
        
        return [JobPayload (
            codigo: "BLL-ATM-RVH",
            shopID: 0,
            itemID: 0,
            url: ""
        ),JobPayload (
            codigo: "BBG-XRA-KGH",
            shopID: 0,
            itemID: 0,
            url: ""
        ),JobPayload (
            codigo: "AUY-MXD-JLB",
            shopID: 0,
            itemID: 0,
            url: ""
        ),JobPayload (
            codigo: "BTL-YPD-JMR",
            shopID: 0,
            itemID: 0,
            url: ""
        ),JobPayload (
            codigo: "AAA-BBB-CCC",
            shopID: 0,
            itemID: 0,
            url: ""
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
