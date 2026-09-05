//
//  MonitorAgent.swift
//  LocalPackage
//

import Foundation

@MainActor
final class MonitorAgent {

    private var URL_MONITOR: String
    private var SESSION_ID: String
    private var TRIGGER_MONITOR: Regex<Substring>
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
        monitorInterval: Duration
    ) {

        self.store = store
        self.URL_MONITOR = urlMonitor
        self.TRIGGER_MONITOR = try! Regex(triggerMonitor)
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
                    url: item.url,
                    username: item.username
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
            //var codigos: Set<String> = []
            var codigos: [String: String] = [:]
            
            if let commentsResult = try? JSONDecoder().decode(CommentsResponse.self, from: data) {
                for comment in commentsResult.data.comments {
                    let codigosComment = comment.content.matches(of: TRIGGER_MONITOR).map { String($0.output) }
                    print("------> Comentario: \(comment.content)")
                    print("------> REGEX: \(codigosComment)")
                    print("------> Username: \(comment.username)")
                    //codigos.formUnion(codigosComment)
                    codigos = codigosComment.reduce(into: codigos) { resultado, codigo in
                        resultado[codigo] = comment.username
                    }
                }
            } else {
                codigos = String(data: data, encoding: .utf8)?
                    .matches(of: TRIGGER_MONITOR)
                    .reduce(into: [String: String]()) { result, match in
                        result[String(match.output)] = "pending"
                    } ?? [:]
            }
            
            for codigo in codigos {
                listaJobPayload.append(JobPayload (codigo: codigo.key, param1: 0, param2: 0, url: "", username: codigo.value))
            }
            
            return listaJobPayload
        } catch {
            print("Monitor Agent: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func fetchApiChangesMock() async throws -> [JobPayload] {
        
        return [/*JobPayload (
            codigo: randomCodigo(),//"BLL-ATM-RVH",
            param1: 0,
            param2: 0,
            url: "",
            username: ""
        ),*/JobPayload (
            codigo: "CFE-QDM-TBT",
            param1: 0,
            param2: 0,
            url: "",
            username: "CFE-QDM-TBT"
        ),JobPayload (
            codigo: "ATE-AMS-FZC",
            param1: 0,
            param2: 0,
            url: "",
            username: "CFE-QDM-TBT"
        ),JobPayload (
            codigo: "FGS-RWT-ZDF",
            param1: 0,
            param2: 0,
            url: "",
            username: "CFE-QDM-TBT"
        ),JobPayload (
            codigo: "DGR-JEV-QSN",
            param1: 0,
            param2: 0,
            url: "",
            username: "CFE-QDM-TBT"
        )
            /*JobPayload (
                codigo: "TAM3330",
                param1: 0,
                param2: 0,
                url: "",
                username: "TAM3330"
            ),JobPayload (
                codigo: "AZU2658",
                param1: 0,
                param2: 0,
                url: "",
                username: "AZU2658"
            ),JobPayload (
                codigo: "GLO2059",
                param1: 0,
                param2: 0,
                url: "",
                username: "GLO2059"
            ),JobPayload (
                codigo: "TAM3672",
                param1: 0,
                param2: 0,
                url: "",
                username: "TAM3672"
            )*/
            /*,JobPayload (
            codigo: "BZZ-FGN-LTQ",
            param1: 0,
            param2: 0,
            url: "",
          username: ""
        ),JobPayload (
            codigo: "CJL-ERN-DSF",
            param1: 0,
            param2: 0,
            url: "",
          username: ""
        ),JobPayload (
            codigo: "BXR-TRQ-NQG",
            param1: 0,
            param2: 0,
            url: "",
          username: ""
        ),JobPayload (
            codigo: "BRC-KXY-FNJ",
            param1: 0,
            param2: 0,
            url: "",
          username: ""
        ),JobPayload (
            codigo: "AYT-VLG-NRT",
            param1: 0,
            param2: 0,
            url: "",
          username: ""
        ),JobPayload (
            codigo: "AUZ-XWT-UXU",
            param1: 0,
            param2: 0,
            url: "",
          username: ""
        ),JobPayload (
            codigo: "AVW-ZPA-XYK",
            param1: 0,
            param2: 0,
            url: "",
          username: ""
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
