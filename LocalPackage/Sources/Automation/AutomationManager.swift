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
    
    //public var allJobs: [String] = []
    public let actionEvents: AsyncStream<ActionEvent>
    private let continuation: AsyncStream<ActionEvent>.Continuation
    
    public init(){
        let (stream, continuation) = AsyncStream.makeStream(of: ActionEvent.self)
        
        self.actionEvents = stream
        self.continuation = continuation
    }

    var isRunning = false

    public func start(naviConfig: String, cookieList: String) {

        guard !isRunning else {
            return
        }
        
        do {
            config = try JSONDecoder().decode(NaviConfig.self, from: Data(naviConfig.utf8))
            
            monitorAgent = MonitorAgent(
                store: store,
                urlMonitor: config.urlMonitor,
                sessionId: config.sessionId,
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
        }

        monitorAgent?.start()
        flowAgent?.start()
        actionAgent?.start()

        isRunning = true
        
        Task {
            let stream = await store.events()
            for await job in stream {
                if Task.isCancelled { break }
                
                guard job.status == .ok
                else { continue }
                
                print("AutomationManager - enviando pro browser: \(job.payload.codigo)")
                emit(.openPage(codigo: job.payload.codigo, url: job.payload.url, script: config.script))
            }
            
            //await syncJobs()
        }
    }

    public func stop() {

        monitorAgent?.stop()
        flowAgent?.stop()
        actionAgent?.stop()

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
    
    func emit(_ event: ActionEvent) {
        continuation.yield(event)
    }
    func finish() {
        continuation.finish()
    }
    
}
