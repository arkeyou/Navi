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
    private let am: AutomationManager
    
    private var count: Int = 0
    private let codes: [String] = ["AUG-TPF-TVA", "FXP-SBJ-XSN", "FRM-VWU-PFF", "FKJ-VGL-RVE", "AZL-SRD-CFH", "ABK-WCC-FAP", "ASX-AME-GZJ", "FRL-JMM-RWE", "BZH-CFW-GXY", "AEF-GGF-UGU", "AGQ-DQF-WJK", "ABX-BUU-XJB", "FXG-DWQ-VSN", "DAW-PLA-GYE", "CHG-MMX-STC", "CJS-XLP-PQN", "AZE-TGU-TTK", "BXE-WZF-UJT", "APX-KBU-TAF", "BEV-PRB-WPR", "DDF-BWT-JPE", "DKS-KMY-TYE", "BWU-JDD-CGD", "ERT-XXS-UYM", "END-TCF-XSI", "EAW-EGQ-ATE", "EXT-MXG-SWE", "DGR-LAN-QSN", "FXE-KAV-PFF", "DXG-YLG-PSN", "DRT-GPP-WSN", "FUH-YVA-RSN", "DDS-KUD-XSN", "FKX-ZQP-WSN", "DKB-PTJ-TXE", "FXD-QTF-RSN", "FKM-CBK-FCN", "AEZ-WWX-PUD", "ART-ZLN-XQA", "FUS-BQM-RJE", "BQR-PFQ-KEH", "EKP-ABW-VZE", "AQJ-GJL-XKE", "DNM-CVG-RSN", "BAD-XNT-BEU", "BNV-RTR-PUR", "FGQ-JCH-BFF", "ABF-QXC-NXW", "AGV-KYQ-CNA", "EAH-LFW-HLB", "AZG-CZX-PCR", "AZE-TGV-MLH", "AUZ-QAS-VGP", "AJF-DAV-FQW", "ADQ-DUZ-KFR", "EDU-WCY-VSN", "DDN-BXB-FXE", "FNV-WFL-HNE", "EKE-ALD-ECM", "ANY-PGR-LLJ", "ASS-LWE-FQL"]
    let usernames: [String] = ["mari_88", "carlosss21", "ana.luiza7", "pedro123", "biazinha_44", "lucasdev99", "juuh_2026", "rafael_mg", "camila33", "brunoo_17", "amanda.shop", "gui1234", "leticia_88", "matheusx9", "feeh_2025", "gabriela77", "rodrigoo21", "dudinha_3", "marcos123", "isabelaa88", "thiagomg7", "larissinha22", "vinicius_09", "carolzinha5", "felipe444", "jessica_27", "andreluiz8", "nathalia33", "gugaa_12", "beatriz_2026", "leonardo77", "juju123", "danielzinho9", "monique_88", "gustavo21", "alineee7", "ricardomg33", "tati_2025", "eduardo123", "paulinha44", "renan_09", "sarahzinha7", "wellington22", "livias2", "arthur_mg", "marianaaa88", "caio1234", "fer_2026", "diegooo17", "clarinha33", "igor_mg9", "priscila_77", "henrique21", "juliaa_08", "otavio123", "vivi_444", "samuelzinho9", "aline.shop27", "bruninha88", "gabriel_2026", "manu123", "robertomg7"]

    init(
        store: JobStore,
        urlMonitor: String,
        triggerMonitor: String,
        sessionId: String,
        cookieList: String,
        monitorInterval: Duration,
        am: AutomationManager
    ) {

        self.store = store
        self.URL_MONITOR = urlMonitor
        self.TRIGGER_MONITOR = try! Regex(triggerMonitor)
        self.SESSION_ID = sessionId
        self.cookies = cookieList
        self.monitorInterval = monitorInterval
        self.am = am
    }

    func start() {

        guard task == nil else { return }
        
        task = Task {
            do {
                while !Task.isCancelled {
                    print("MonitorAgent - monitorando mensagens")
                    try await scan()
                    
                    
                    /*var i = 0;
                    print("automation ------------")
                    await store.all().filter{ $0.status != JobStatus.dupe }.forEach {
                        i += 1
                        print("\(i): \($0.payload.codigo) - \($0.status)")
                    }
                    print("automation ------------")*/
                    //await dump(store.all())
                    am.emit(.sendMsg(message: "˙", stop: false, lineBreak: false))//"."
                    try await Task.sleep(for: monitorInterval)
                    
                    //˙··˙···˙··˙···˙··˙···˙
                    //●··●···●··●···●··●···●
                    //○··○···○··○···○··○···○
                    //◦··◦···◦··◦···◦··◦···◦
                    //•··•···•··•···•··•···•
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
                        //TODO Alterar de modo que nao impacte outros tipos de codigo
                        var codigoTratado = codigo.contains(".")
                            ? codigo.replacingOccurrences(of: ".", with: "-")
                            : codigo
                        //Se o codigo nao tem separacao, adiciona -
                        if codigoTratado.count == 9 &&
                            codigoTratado.allSatisfy({ $0.isLetter }) {
                            codigoTratado = "\(codigoTratado.prefix(3))-\(codigoTratado.dropFirst(3).prefix(3))-\(codigoTratado.dropFirst(6))"
                        }
                        resultado[codigoTratado] = comment.username
                    }
                }
            } else {
                codigos = String(data: data, encoding: .utf8)?
                    .matches(of: TRIGGER_MONITOR)
                    .reduce(into: [String: String]()) { result, match in
                        result[String(match.output)] = "\(match.output)"
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
        count = count+1
        if (count>=codes.count) {
            count = 0
        }
        return [JobPayload (
            codigo: codes[count],
            param1: 0,
            param2: 0,
            url: "",
            username: usernames[count]
        )
        /*JobPayload (
            codigo: randomCodigo(),//"BLL-ATM-RVH",
            param1: 0,
            param2: 0,
            url: "",
            username: ""
        ),JobPayload (
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
            username: "ATE-AMS-FZC"
        ),JobPayload (
            codigo: "FGS-RWT-ZDF",
            param1: 0,
            param2: 0,
            url: "",
            username: "FGS-RWT-ZDF"
        ),JobPayload (
            codigo: "DGR-JEV-QSN",
            param1: 0,
            param2: 0,
            url: "",
            username: "DGR-JEV-QSN"
        )*/
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
