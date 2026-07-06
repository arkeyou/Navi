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

            //while !Task.isCancelled {
                print("MonitorAgent - monitorando mensagens")
                
                do {
                    try await Task.sleep(
                        for: .seconds(5)
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
    
    func stop() {
        task?.cancel()
        task = nil
    }

    private func scan() async throws {

        let apiItems = try await fetchApiChanges()

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
        print(cookies)
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        /*request.setValue("SPC_SI=WKEragAAAABJZ0RuY3pCUxco/wAAAAAAd0xjd2FDM1c=; SPC_R_T_ID=+Lpj2qfSu6VuMIvLboOYTnIhgAYKjsRbNRbh8Rca2sd8Zlzc3IbD+KtX2QBE6inetdDnRCaAWjpbkNdGQD8m1Xr3zAAHEYoYrDbese4Wlsk3beYXCYw7kN9QIqjVe0NPVb7KLBr8QTk0SVJk7fDA6HuaZHLsVKNrdP0CDWj/rDM=; SPC_R_T_IV=d01nc3dXRjRCYXFuSlVoMw==; SPC_T_ID=+Lpj2qfSu6VuMIvLboOYTnIhgAYKjsRbNRbh8Rca2sd8Zlzc3IbD+KtX2QBE6inetdDnRCaAWjpbkNdGQD8m1Xr3zAAHEYoYrDbese4Wlsk3beYXCYw7kN9QIqjVe0NPVb7KLBr8QTk0SVJk7fDA6HuaZHLsVKNrdP0CDWj/rDM=; SPC_T_IV=d01nc3dXRjRCYXFuSlVoMw==; sense_sa_r=s; AC_CERT_D=gqRjZGVrxHeFomtpuDE0MjUxOmNhcHRjaGFfY29va2llX2tleaJrdtEAAaRhbGdv0gAAAGSjZGVrwKJjdMRAAAAADGE52xUo3Wm3iC5rRYtPIg498IF1KHCytnPhbjJaI6YqfVhynmwqpbv6ogr0FzEZ/3RtNpmV6B9rxJ+WP6pjaXBoZXJ0ZXh0xQNWAAAADGB2MtlMthVRu9jKpTWrdtEOibG5Pwayffps5ERF52+RzHqX0R2twdQDtb1V+6dSO116wEY2IW+2KEPy5wq8KWMmVOH4aLZTlka7AZnVHuhrzieV+d/2tPt2JMWPzvj96VgYlgPa7zVKPQF+Ue3AueB+kOCVRYNo4r/3u3j6T88tp7fUFV5hHkQ6DPVdXRRm9uTS0TlAEHb90Afc+zz3NRsrHtVbJNWtObscuoQ7Q3Oi+lTf3HiUgLnN4TecCMBO0fAfphxxg1GJ8xSpymrbxEgLugBuFib3oVfaO+Q29qXSZiB6JaTHeZ5Zx8dY0JJVgqj9MH0pvC9LPPSJAhoJnFHM4vYTWi40xsqKUKjiJQgu8zpLUOETOVKU+J2MCR1Lkod109/fiUIdu6y6PNy0MJbMJb4l6gGuX3OIPAEkMIhfFdCmrVhhAuHzZ0d1lZ04RVHX7Yte2R+vO+eqSW1N2GiDfZ6DzGuEEDo1Fpge+pbHayXxHudsg6sAUPFi7QjTXzphGxHNZV2DfcH5Sn+xuqmE/A9PtrDZjzWC756jdv7lwgd21kmrl6VPY/ZdUALezNqfFOpCkZzTxFHF9mVW1JpGBZRYd/wrx/sZSQrWiOPMiwtZVzEyUsq56v4MTyA0jMf/jRQisHzBXGtWQKc0eAghb03XntK51iRPbiXpBVc5NIr4jh8SMpFFZ9nDFUkakyyl6XZdSFU/00t3NMKjPjESlARhT+IR9P+MXqn1MJF0I5+DplnG055a4JF5FjRpS6KtO+mrVWjIzRn3yk5SLFv6YCqPhw3KXd0f/z6R+lfdfGgFWs4lCZi6T6DbGPQ4++TNbiS1K0kReGYy02U7enYCPQuoteg4ELoy1nZD3kapnkZhmR9IjHSc9HObDN+h+A4TY9+Fi2FaIVKODUlHtPRTHjSGuQzgk72FdNf5AmonC85u8ZUsANMIjU+D63ikQKKlR9QFCEXiewyw72r0h2AVyOjFH57ZfSQBbgwzRcxMo77brWqh7eZ1Pk4hLPJep6SufH6L/V6SrNOm4QCFPs/sPldamlbzBVzG8gOzsfwABqBYwUnOP3O/Kk8gjbpIJ9o1w2EnRSc4LlJHO3/9Uiz73yLPlDM3BS6QrUQpF8iG+Ao=; csrftoken=LKI6sKl3ZALycQ9igPPlys2dbTR3MF8t; CTOKEN=mfKjsHcuEfGlPZ4YbLBmeQ%3D%3D; _sapid=d202b961c162fb0bd75f7563fe9e73fdd7e8fc5a675d9d96127508da; _ga_T69DLR1QPG=GS2.1.s1783026187$o7$g1$t1783026667$j60$l0$h580554024; _fbp=fb.2.1782320243148.442639823167959771; SPC_CDS_CHAT=04a07704-4b18-436d-a7b8-87c1365c2e7b; SPC_SC_MAIN_SHOP_SA_UD=0; SPC_SC_SESSION=g07RyVWK590+3Uho6xQorOfYmTolLhVPmMSv7JmammKiEIQj0+pf0kccsbhRvRbQFzkT6razGOxCoUcFePw4FO3ljYih3GisLDzADyH0ZFJ4ZT4FiwL9MkrFooGEruN9bK+UxWe7G8+jiY6gX8acyIp7VhBl5g/9daxI43uQuXJHsd6qQwHjmU8GefruaVsRPqePcBAxzCX2XcSt0rszbqfTeBIgIHJojgjL5JbH/geIylsSiBMa1RKrdFke4+n+228HXnz4OmyFfb/0jxD7TsA==_1_849818949; SPC_STK=B7QLZFS560DQVIwcZnNhl2N/xjgEQpEO98M+J8H/xsSybvgapZUg2Gsj7tXwkP0kcl407n8YYjNlbdgZiAX4eg+9tR10sAYnSlMWZrg0PNk0GyghEgNB3FhmPj59wKvrkS933NAusXTRyunrLOgVd8l4N4NAMUeFxVgZnpd6mTF/SnNLuPV99BvHqnW+h9bLWedf0TEtM6JqUtcxTAybkRdG0ZYJfCB36seKVI8+9/TODVF1vEI2QP2/hRAhfkZ6qcOsIflRoAyYPcV8f6Go8VvDrExxY8rIXZt+s4XxG0KpTeMdjOXZEYpT4SyCT5kY10pWx3DT0FpxxfpD9vnUgGjQsnzYdG5gcBFnyExxzbAHT3tEr4SzdfWryTPS4xs+F3Ta/lJbwsh6znzn8ONLPEsDTHLH6UrskSprLregtmmpsH1fvIlbD8zXLvW/gdzZYeqgqCWHXsgtvoth+oBSCij13Df7RcDiCMH/vnvSKlRp2WnCvIOvJP0dy7cxNMJy; SPC_CLIENTID=bDdkbWcxb3NNZDBQfqtqmaxyujajrvbb; SPC_ST=dGtuekRZcmNDNndwYkxDdqnclqcQiocliPdEQ4OcNri0qQMRNDCOJcP7GRz5RtBrKiwO8lo6bCU9ZRYbMOQnJc5Vaja0dbvFIRnMH2lsp2uEZfAom91F903WIhmXRZzDPCN39d3BIludaTYGbwlQvzDIhuIFGvrjMCQlILEOG2FZqifw6T5ID12eTZhC631ZzvW0v8YJUrDgl+5nYVBnKw==.AK+Bj+/RhOp9f6U7wUPfyvQhfr5993usSuOf3TxL3eQa; SPC_U=849818949; SPC_EC=-; _ga_VF5H5BSHNS=GS2.1.s1782906328$o1$g0$t1782906532$j60$l0$h0; language=pt-BR; _ga=GA1.1.956376934.1782320243; _gcl_au=1.1.407490379.1782320243; SC_DFP=nbrpZveHjccLipUfRwmUvKkxSIZAdajg; REC_T_ID=d1b64440-c56e-11f0-8ad2-7a5bcdc273e2; SPC_F=l7dmg1osMd0PgIwQOgbMCOFuIe7XyMx6",
        forHTTPHeaderField: "Cookie")*/
        
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
        
        /*return [JobPayload (
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
        )]*/
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
