//
//  MonitorAgent.swift
//  LocalPackage
//

import Foundation

@MainActor
final class MonitorAgent {

    private var URL_MONITOR: String
    private var SESSION_ID: String
    private var TRIGGER: Regex<Substring>
    private let monitorInterval: Duration
    
    private let store: JobStore
    private var task: Task<Void, any Error>?
    private let cookies: String

    init(
        store: JobStore,
        urlMonitor: String,
        triggerMonitor: String,
        sessionId: String,
        cookieList: String,
        monitorInterval: Duration = .seconds(4)
    ) {

        self.store = store
        self.URL_MONITOR = urlMonitor
        self.TRIGGER = try! Regex(triggerMonitor)
        self.SESSION_ID = sessionId
        self.cookies = cookieList
        self.monitorInterval = monitorInterval
    }

    func start() {

        guard task == nil else { return }
        
        task = Task {
            do {
                while !Task.isCancelled {
                    print("MonitorAgent - monitorando mensagens")
                    try await Task.sleep(for: monitorInterval)
                    try await scan()
                    
                    
                    var i = 0;
                    print("------------")
                    await store.all().filter{ $0.status != JobStatus.dupe }.forEach {
                        i += 1
                        print("\(i): \($0.payload.codigo) - \($0.status)")
                    }
                    print("------------")
                    //await dump(store.all())
                }
            } catch is CancellationError {
                
            } catch {
                print("Parou Monitor")
                throw AutomationError.monitor(error)
            }
        }
    }
    
    func wait() async throws {
        try await task?.value
    }
    
    func stop() {
        task?.cancel()
        task = nil
    }

    private func scan() async throws {

        let apiItems = try await fetchApiChanges()
        //let apiItems = try await fetchApiChangesMock()

        for item in apiItems {
            //print("MonitorAgent - detectou codigo "+item.codigo)
            let job = Job(
                id: UUID(),
                payload: JobPayload (
                    codigo: item.codigo,
                    param1: item.param1,
                    param2: item.param2,
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
        
        let urlFormatada = String(format: URL_MONITOR, arguments: [(SESSION_ID.isEmpty ? "0" : SESSION_ID) ])
        guard let url = URL(string: urlFormatada) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        //print(cookies)
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        print(String(data: data, encoding: .utf8) ?? "Nao conseguiu ler o body")
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: responseBody])
        }
        
        do {
            var listaJobPayload: [JobPayload] = []
            var codigos = [] as [String]
            
            if let commentsResult = try? JSONDecoder().decode(CommentsResponse.self, from: data) {
                for comment in commentsResult.data.comments {
                    codigos = comment.content.matches(of: TRIGGER).map { String($0.output) }
                    print("------> Comentario: \(comment.content)")
                    print("------> REGEX: \(codigos)")
                }
            } else {
                codigos = (String(data: data, encoding: .utf8)?.matches(of: TRIGGER).map { String($0.output) })!
            }
            
            for codigo in codigos {
                listaJobPayload.append(JobPayload (codigo: codigo, param1: 0, param2: 0, url: ""))
            }
            
            return listaJobPayload
        } catch {
            print("Monitor Agent: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func fetchApiChangesMock() async throws -> [JobPayload] {
        
        return [JobPayload (
            codigo: randomCodigo(),//"BLL-ATM-RVH",
            param1: 0,
            param2: 0,
            url: ""
        ),JobPayload (
            codigo: "CFE-QDM-TBT",
            param1: 0,
            param2: 0,
            url: ""
        ),JobPayload (
            codigo: "ATE-AMS-FZC",
            param1: 0,
            param2: 0,
            url: ""
        ),JobPayload (
            codigo: "FGS-RWT-ZDF",
            param1: 0,
            param2: 0,
            url: ""
        ),JobPayload (
            codigo: "DGR-JEV-QSN",
            param1: 0,
            param2: 0,
            url: ""
        
        )/*,JobPayload (
            codigo: "BZZ-FGN-LTQ",
            param1: 0,
            param2: 0,
            url: ""
        ),JobPayload (
            codigo: "CJL-ERN-DSF",
            param1: 0,
            param2: 0,
            url: ""
        ),JobPayload (
            codigo: "BXR-TRQ-NQG",
            param1: 0,
            param2: 0,
            url: ""
        ),JobPayload (
            codigo: "BRC-KXY-FNJ",
            param1: 0,
            param2: 0,
            url: ""
        ),JobPayload (
            codigo: "AYT-VLG-NRT",
            param1: 0,
            param2: 0,
            url: ""
        ),JobPayload (
            codigo: "AUZ-XWT-UXU",
            param1: 0,
            param2: 0,
            url: ""
        ),JobPayload (
            codigo: "AVW-ZPA-XYK",
            param1: 0,
            param2: 0,
            url: ""
        )*/]
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
