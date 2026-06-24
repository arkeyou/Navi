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

    public init(){
    }

    var isRunning = false

    public func start() {

        guard !isRunning else {
            return
        }

        let browser = FakeBrowser()

        monitorAgent = MonitorAgent(
            store: store
        )

        flowAgent = FlowAgent(
            store: store
        )

        actionAgent = ActionAgent(
            store: store,
            browser: browser
        )

        monitorAgent?.start()
        flowAgent?.start()
        actionAgent?.start()

        isRunning = true
    }

    public func stop() {

        monitorAgent?.stop()
        flowAgent?.stop()
        actionAgent?.stop()

        isRunning = false
    }
    
    /*func listJobs(type: JobStatus) -> [Job] {
        return store.jobs(status: .valid)
    }*/

}
