import Foundation

struct JavaScriptBuilder {
    
    enum BuilderError: Error, LocalizedError {
        
        case missingParameter(String)
        case unknownType(String)
        
        var errorDescription: String? {
            switch self {
            case .missingParameter(let parameter):
                return "Parâmetro obrigatório não informado: \(parameter)"
                
            case .unknownType(let type):
                return "Tipo de script não suportado: \(type)"
            }
        }
    }
    
    
    static func generate(
        _ automationScript: AutomationScript
    ) throws -> String {
        
        switch automationScript.type {
            
        case "confirm":
            
            guard let message = automationScript.message,
                  !message.isEmpty else {
                throw BuilderError.missingParameter("message")
            }
            
            return "confirm(\"\(message)\") ? true : false;"
            
            
        case "exists":
            
            guard let selector = automationScript.selector,
                  !selector.isEmpty else {
                throw BuilderError.missingParameter("selector")
            }
            
            return "document.querySelectorAll(\"\(selector)\").length > 0"
            
            
        case "click":
            
            guard let selector = automationScript.selector,
                  !selector.isEmpty else {
                throw BuilderError.missingParameter("selector")
            }
            
            return """
            (document.querySelectorAll("\(selector)")).forEach(button => button.click());
            """
            
            
        default:
            
            throw BuilderError.unknownType(
                automationScript.type
            )
        }
    }
}
