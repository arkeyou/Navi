//
//  AutomationManager.swift
//  LocalPackage
//

import Foundation

@Observable @MainActor public class AutomationManager {

    private let store = JobStore()

    private var monitorAgent: MonitorAgent?
    private var flowAgent: FlowAgent?
    private var actionAgent: ActionAgent?
    
    private var config: NaviConfig = NaviConfig()
    
    private let MONITOR_LIVE_ONLINE_INTERVAL = Duration.seconds(20)
    
    //public var allJobs: [String] = []
    public let actionEvents: AsyncStream<ActionEvent>
    private let continuation: AsyncStream<ActionEvent>.Continuation
    
    public init(){
        let (stream, continuation) = AsyncStream.makeStream(of: ActionEvent.self)
        
        self.actionEvents = stream
        self.continuation = continuation
    }

    public private(set) var isRunning = false
    private(set) var eventStreamTask: Task<Void, Never>? = nil
    private(set) var monitorLiveStreamTask: Task<Void, any Error>? = nil

    public func start(naviConfig: String, sessionId: String = "", cookieList: String) async {

        guard !isRunning else {
            return
        }
        
        var sessionIdLocal = sessionId
        
        do {
            print(naviConfig.utf8)
            config = try JSONDecoder().decode(NaviConfig.self, from: Data(naviConfig.utf8))
            
            if sessionId.isEmpty {
                sessionIdLocal = sessionId
            }
            
            //Verifica se a sessao esta ativa
            /*if let urlSessionInfo = config.urlSessionInfo {
                do {
                    _ = try await getSessionIsOpen(urlSessionInfo: urlSessionInfo, sessionId: sessionIdLocal, cookies: cookieList)
                } catch let error as SessionError {
                    emit(.sendMsg(message: "\nSession Error: \(error.message)"))
                    return
                } catch {
                    emit(.sendMsg(message: "\n\(error.localizedDescription)"))
                    return
                }
            }*/
            
            monitorAgent = MonitorAgent(
                store: store,
                urlMonitor: config.urlMonitor,
                triggerMonitor: config.triggerMonitor,
                sessionId: sessionIdLocal,
                cookieList: cookieList
            )

            flowAgent = FlowAgent(
                store: store,
                urlFlow: config.urlFlow
            )

            actionAgent = ActionAgent(
                store: store,
                urlAction: config.urlAction
            )
        } catch {
            print("Decoding failed: \(error.localizedDescription)")
            emit(.sendMsg(message: "\nDecoding failed: \(error.localizedDescription)"))
            return
        }

        //Monitora se a live ainda esta online
        monitorLiveStreamTask = Task {
            while !Task.isCancelled {
                try await Task.sleep(for: MONITOR_LIVE_ONLINE_INTERVAL)
                print("Verificando se a live ainda esta online...")
                if let urlSessionInfo = config.urlSessionInfo {
                    do {
                        _ = try await getSessionIsOpen(urlSessionInfo: urlSessionInfo, sessionId: sessionIdLocal, cookies: cookieList)
                    } catch let error as SessionError {
                        emit(.sendMsg(message: "\nSession Error: \(error.message)"))
                        return
                    } catch {
                        emit(.sendMsg(message: "\n\(error.localizedDescription)"))
                        return
                    }
                }
            }
        }
        
        monitorAgent?.start()
        flowAgent?.start()
        actionAgent?.start()
        
        isRunning = true
        
        eventStreamTask = Task {
            let stream = await store.events()
            for await job in stream {
                if Task.isCancelled { break }
                
                guard job.status == .ok
                else { continue }
                
                print("AutomationManager - enviando pro browser: \(job.payload.codigo)")
                emit(.openPage(codigo: job.payload.codigo, url: job.payload.url, script: config.script, scriptVerify: config.scriptVerify))
            }
            //await syncJobs()
        }
        
        do {
            try await monitorAgent?.wait()
            try await flowAgent?.wait()
            try await actionAgent?.wait()
        } catch let error as AutomationError {
            print("\nAutomationManager: \(error.localizedDescription)")
            
            var errorMsg = ""
            switch error {
                case .monitor(let underlying):
                    errorMsg.append("Monitor failed: \(underlying.localizedDescription)")

                case .flow(let underlying):
                    errorMsg.append("Flow failed: \(underlying.localizedDescription)")

                case .action(let underlying):
                    errorMsg.append("Action failed: \(underlying.localizedDescription)")
                }
            emit(.sendMsg(message: "\n\(errorMsg)"))
            return
        } catch {
            print("\nAutomationManager: \(error.localizedDescription)")
            emit(.sendMsg(message: "\nAutomationManager: \(error.localizedDescription)"))
            return
        }
        
    }

    public func stop() {

        monitorAgent?.stop()
        flowAgent?.stop()
        actionAgent?.stop()

        eventStreamTask?.cancel()
        eventStreamTask = nil
        
        monitorLiveStreamTask?.cancel()
        monitorLiveStreamTask = nil

        isRunning = false
    }
    
    /*func syncJobs() async {
        await store.all().map(Set.init).forEach(\.ok) {
            emit(.openPage(item.payload.codigo))
            
            var current = item
            current.status = .ok
            current.updatedAt = .now
            //store.update(item)
        }
    }*/
    
    func getSessionIsOpen(urlSessionInfo: String, sessionId: String, cookies: String) async throws -> Bool {
        do {
            let urlFormatada = String(format: urlSessionInfo, arguments: [sessionId])
            guard let url = URL(string: urlFormatada) else { throw URLError(.badURL) }
            var request = URLRequest(url: url)
            //print(cookies)
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            //print(String(data: data, encoding: .utf8) ?? "Nao conseguiu ler o body")
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                throw URLError(.badServerResponse)
            }
            
            let sessionInfo = try JSONDecoder().decode(SessionInfo.self, from: data)
            if (sessionInfo.msg == nil) {
                if sessionInfo.data?.sessionStatus == 1 {
                    
                    return true
                }
                throw SessionError.live("Esta live não está online!")
            }

            throw SessionError.login("Gentileza efetuar o login!")
        } catch let error as SessionError {
            throw error
        } catch {
            throw SessionError.error("\(error.localizedDescription)")
        }
    }
    
    enum SessionError: LocalizedError {
        case live(String)
        case login(String)
        case error(String)
        
        var message: String {
            switch self {
                case .live(let message),
                     .login(let message),
                     .error(let message):
                    return message
            }
        }
        
        var errorDescription: String? {
            message
        }
    }
    
    func emit(_ event: ActionEvent) {
        continuation.yield(event)
    }
    func finish() {
        continuation.finish()
    }
    
    struct SessionInfo: Codable {
        //let code: Int
        let msg: String?
        let data: SessionData?
    }

    struct SessionData: Codable {
        //let sessionId: Int64
        //let sessionTitle: String
        //let sessionCoverUrl: String
        //let sessionStreamingUrl: String
        //let sessionStreamingUrlExpireTimestamp: Int64
        let lsEndTime: Int64?
        let lsStartTime: Int64
        let sessionStatus: Int
        //let isFoodSession: Bool
    }

    
}
