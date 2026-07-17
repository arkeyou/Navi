//
//  FlowAgent.swift
//  LocalPackage
//
import Foundation

@MainActor
final class FlowAgent {

    private var URL_SEARCH: String

    private let store: JobStore
    private var task: Task<Void, any Error>?

    init(
        store: JobStore,
        urlFlow: String
    ) {
        self.store = store
        self.URL_SEARCH = urlFlow
    }

    func start() {
        
        guard task == nil else { return }
        
        task = Task {

            let stream =
                await store.events()
            print("FlowAgent - quantidade de jobs: \(stream)")
            for await job in stream {
                if Task.isCancelled { break }

                guard job.status == .added
                else { continue }

                try await validate(job)
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

    private func validate (_ job: Job) async throws {
        var current = job
        
        //print("FlowAgent - validando: \(current.payload.codigo)")
        
        current.status = .isValidating
        current.updatedAt = .now
        
        await store.update(current)
        
        let isDuplicate =
        await store.hasDuplicate(
            code: current.payload.codigo,
            excluding: current.id
        )
        
        if isDuplicate {
            //print("FlowAgent - duplicado: \(current.payload.codigo)")
            
            current.status = .dupe
            current.updatedAt = .now
            
            await store.update(current)
            
            return
        }
        
        do {
            let searchResult = try await fetchApi(codigo: current.payload.codigo)
            print("FlowAgent - processado: \(current.payload.codigo) - itemID: \(Int64(searchResult.directSearchResult.item.itemID)) - shopID: \(Int64(searchResult.directSearchResult.item.shopID))")

            current.status = .valid
            current.updatedAt = .now
            current.payload.itemID = Int64(searchResult.directSearchResult.item.itemID)
            current.payload.shopID = Int64(searchResult.directSearchResult.item.shopID)

            await store.update(current)
        } catch {
            print("error fetch")
            throw AutomationError.flow(error)
        }
    }
    
    private func fetchApi(codigo: String) async throws -> SearchResponse {
        
        guard let url = URL(string: "\(URL_SEARCH)\(codigo)") else { throw URLError(.badURL) }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        
        /*if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print(json)
        }*/
        
        do {
            let searchResult = try JSONDecoder().decode(SearchResponse.self, from: data)
            return searchResult
        } catch {
            print("Flow Agent: \(error.localizedDescription)")
            throw error
        }
        
    }
}
