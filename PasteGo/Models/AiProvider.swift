import Foundation
import GRDB

/// AI provider kind
enum ProviderKind: String, Codable, CaseIterable, DatabaseValueConvertible {
    case openai
    case claude
    case kimi
    case minimax
    case ollama

    var label: String {
        switch self {
        case .openai: "OpenAI"
        case .claude: "Claude (Anthropic)"
        case .kimi: "Kimi (月之暗面)"
        case .minimax: "MiniMax (海螺)"
        case .ollama: "Ollama (本地)"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .openai: "https://api.openai.com/v1"
        case .claude: "https://api.anthropic.com/v1"
        case .kimi: "https://api.moonshot.cn/v1"
        case .minimax: "https://api.minimax.chat/v1"
        case .ollama: "http://localhost:11434"
        }
    }

    var defaultModels: [String] {
        switch self {
        case .openai: ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"]
        case .claude: ["claude-sonnet-4-20250514", "claude-haiku-4-20250414", "claude-opus-4-20250514"]
        case .kimi: ["moonshot-v1-128k", "moonshot-v1-32k", "moonshot-v1-8k"]
        case .minimax: ["MiniMax-Text-01", "abab6.5s-chat", "abab5.5-chat"]
        case .ollama: ["llama3", "mistral", "codellama", "qwen2"]
        }
    }

    var needsApiKey: Bool {
        self != .ollama
    }

    var color: String {
        switch self {
        case .openai: "#10a37f"
        case .claude: "#d97706"
        case .kimi: "#6366f1"
        case .minimax: "#ec4899"
        case .ollama: "#8b5cf6"
        }
    }
}

/// An AI service provider configuration
struct AiProvider: Identifiable, Equatable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "ai_providers"

    var id: String
    var name: String
    var kind: ProviderKind
    var endpoint: String
    var model: String
    var apiKey: String
    var isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, kind, endpoint, model
        case apiKey = "api_key"
        case isDefault = "is_default"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["kind"] = kind.rawValue
        container["endpoint"] = endpoint
        container["model"] = model
        container["api_key"] = apiKey
        container["is_default"] = isDefault ? 1 : 0
    }

    init(row: Row) {
        id = row["id"]
        name = row["name"]
        kind = ProviderKind(rawValue: row["kind"]) ?? .openai
        endpoint = row["endpoint"]
        model = row["model"]
        apiKey = row["api_key"]
        isDefault = (row["is_default"] as Int) != 0
    }

    init(id: String = UUID().uuidString, name: String = "", kind: ProviderKind = .openai,
         endpoint: String = "", model: String = "", apiKey: String = "", isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.kind = kind
        self.endpoint = endpoint.isEmpty ? kind.defaultEndpoint : endpoint
        self.model = model.isEmpty ? (kind.defaultModels.first ?? "") : model
        self.apiKey = apiKey
        self.isDefault = isDefault
    }
}
