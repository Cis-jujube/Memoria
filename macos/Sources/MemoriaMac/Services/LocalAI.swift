import Foundation

public enum DeepSeekModel: String, CaseIterable, Identifiable, Sendable {
    case flash = "deepseek-v4-flash"
    case pro = "deepseek-v4-pro"

    public var id: String { rawValue }
    public var title: String { self == .flash ? "Flash" : "Pro" }

    public var thinkingMode: Bool {
        self == .pro
    }
}

public enum LanguagePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case zhCN = "zh-CN"
    case en

    public var id: String { rawValue }
}

public struct NativeSettings: Equatable, Sendable {
    public var model: DeepSeekModel = .flash
    public var deepThinking = false
    public var language: LanguagePreference = .system
    public var hasAPIKey = false

    public init(
        model: DeepSeekModel = .flash,
        deepThinking: Bool = false,
        language: LanguagePreference = .system,
        hasAPIKey: Bool = false
    ) {
        self.model = model
        self.deepThinking = deepThinking
        self.language = language
        self.hasAPIKey = hasAPIKey
    }
}

public struct NativeCopy {
    public let aiInboxTitle: String
    public let whySuggested: String
    public let settingsTitle: String
    public let deepSeekSectionTitle: String
    public let apiKeyPlaceholder: String
    public let saveKey: String
    public let testConnection: String
    public let removeKey: String
    public let modelLabel: String
    public let deepThinkingLabel: String
    public let languageLabel: String
    public let deepseekPrivacyNote: String
    public let missingKeyMessage: String
    public let sendToInbox: String
}

public func nativeCopy(for language: LanguagePreference) -> NativeCopy {
    switch resolvedLanguage(language) {
    case .zhCN:
        NativeCopy(
            aiInboxTitle: "待确认",
            whySuggested: "为什么建议这样记",
            settingsTitle: "设置",
            deepSeekSectionTitle: "DeepSeek 接入",
            apiKeyPlaceholder: "粘贴你的 DeepSeek API key",
            saveKey: "保存密钥",
            testConnection: "测试连接",
            removeKey: "移除密钥",
            modelLabel: "模型",
            deepThinkingLabel: "深度思考",
            languageLabel: "界面语言",
            deepseekPrivacyNote: "开启 AI 识别后，你输入的记忆内容会发送给 DeepSeek 处理。密钥只保存在本机安全存储里，不写进本地数据库。",
            missingKeyMessage: "还没有保存 DeepSeek API key。先去设置里填一下，再用 AI 识别。",
            sendToInbox: "发送到待确认"
        )
    case .en, .system:
        NativeCopy(
            aiInboxTitle: "AI Inbox",
            whySuggested: "Why AI suggested this",
            settingsTitle: "Settings",
            deepSeekSectionTitle: "DeepSeek",
            apiKeyPlaceholder: "Paste your DeepSeek API key",
            saveKey: "Save key",
            testConnection: "Test connection",
            removeKey: "Remove key",
            modelLabel: "Model",
            deepThinkingLabel: "Deep thinking",
            languageLabel: "Language",
            deepseekPrivacyNote: "AI capture sends the text you enter to DeepSeek. Your API key stays in local secure storage and is not written to SQLite.",
            missingKeyMessage: "No DeepSeek API key is saved yet. Add one in Settings before using AI capture.",
            sendToInbox: "Send to AI Inbox"
        )
    }
}

public func resolvedLanguage(_ language: LanguagePreference) -> LanguagePreference {
    if language != .system {
        return language
    }
    return (Locale.preferredLanguages.first ?? "").lowercased().hasPrefix("zh") ? .zhCN : .en
}

public struct DeepSeekChatRequest: Encodable, Sendable {
    public struct Message: Encodable, Sendable {
        public let role: String
        public let content: String

        public init(role: String, content: String) {
            self.role = role
            self.content = content
        }
    }

    struct ResponseFormat: Encodable, Sendable {
        let type: String
    }

    struct Thinking: Encodable, Sendable {
        let type: String
    }

    let model: String
    let messages: [Message]
    let responseFormat: ResponseFormat
    let thinking: Thinking
    let reasoningEffort: String?
    let temperature: Double
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
        case thinking
        case reasoningEffort = "reasoning_effort"
        case temperature
        case maxTokens = "max_tokens"
        case stream
    }
}

public struct DeepSeekConnectionResult: Equatable, Sendable {
    public let model: String
    public let ok: Bool
    public let service: String?

    public var statusMessage: String {
        if let service {
            return "DeepSeek connection passed with \(model) (\(service))."
        }
        return "DeepSeek connection passed with \(model)."
    }
}

public func makeDeepSeekRequest(
    text: String,
    settings: NativeSettings
) -> DeepSeekChatRequest {
    let systemPrompt = """
    Extract friend relationship facts from student-life notes. Keep sensitive facts minimal, evidence-backed, and ready for human review before saving.
    Return only valid JSON. Do not include markdown or prose.
    The JSON object must use this exact top-level shape:
    {"people":[],"reminders":[],"giftIdeas":[]}
    """

    return DeepSeekChatRequest(
        model: settings.model.rawValue,
        messages: [
            .init(role: "system", content: systemPrompt),
            .init(
                role: "user",
                content: "Locale: \(resolvedLanguage(settings.language).rawValue)\nTimezone: \(TimeZone.current.identifier)\nNote:\n\(text)"
            )
        ],
        responseFormat: .init(type: "json_object"),
        thinking: .init(type: settings.deepThinking ? "enabled" : "disabled"),
        reasoningEffort: settings.deepThinking ? "high" : nil,
        temperature: 0.1,
        maxTokens: 1600,
        stream: false
    )
}

public struct DeepSeekClient: Sendable {
    public init() {}

    public func testConnection(apiKey: String, settings: NativeSettings) async throws -> DeepSeekConnectionResult {
        let request = makeConnectionTestRequest(settings: settings)
        let content = try await sendChatCompletion(request, apiKey: apiKey)
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ok = json["ok"] as? Bool,
              ok else {
            throw LocalAIError.invalidTestResponse
        }

        return DeepSeekConnectionResult(
            model: request.model,
            ok: ok,
            service: json["service"] as? String
        )
    }

    public func extractMemory(
        rawEntry: RawEntry,
        knownPeople: [FriendPerson],
        knownThemes: [Theme],
        apiKey: String,
        settings: NativeSettings
    ) async throws -> ExtractMemoryResponse {
        let content = try await sendChatCompletion(
            makeExtractMemoryDeepSeekRequest(rawEntry: rawEntry, knownPeople: knownPeople, knownThemes: knownThemes, settings: settings),
            apiKey: apiKey
        )

        return try AIJSONParser().parseExtractMemoryResponse(content: content)
    }

    private func sendChatCompletion(_ chatRequest: DeepSeekChatRequest, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(chatRequest)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw LocalAIError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                throw LocalAIError.networkUnavailable
            default:
                throw LocalAIError.network(error.localizedDescription)
            }
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocalAIError.invalidResponse
        }
        let errorBody = String(data: data, encoding: .utf8) ?? ""
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw LocalAIError.invalidKey
        }
        if httpResponse.statusCode == 429 {
            throw LocalAIError.rateLimited
        }
        if (httpResponse.statusCode == 400 || httpResponse.statusCode == 404),
           errorBody.localizedCaseInsensitiveContains("model") {
            throw LocalAIError.modelUnavailable(chatRequest.model)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LocalAIError.httpStatus(httpResponse.statusCode, errorBody)
        }
        let decoded = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalAIError.emptyContent
        }
        return content
    }
}

public func makeConnectionTestRequest(settings: NativeSettings) -> DeepSeekChatRequest {
    DeepSeekChatRequest(
        model: settings.model.rawValue,
        messages: [
            .init(
                role: "system",
                content: "Return only valid json. No markdown."
            ),
            .init(
                role: "user",
                content: #"Return exactly {"ok":true,"service":"deepseek"} as a json object."#
            )
        ],
        responseFormat: .init(type: "json_object"),
        thinking: .init(type: settings.model.thinkingMode || settings.deepThinking ? "enabled" : "disabled"),
        reasoningEffort: settings.model.thinkingMode || settings.deepThinking ? "high" : nil,
        temperature: settings.model.thinkingMode || settings.deepThinking ? 0 : 0.1,
        maxTokens: 64,
        stream: false
    )
}

public func makeExtractMemoryDeepSeekRequest(
    rawEntry: RawEntry,
    knownPeople: [FriendPerson],
    knownThemes: [Theme],
    settings: NativeSettings
) -> DeepSeekChatRequest {
    DeepSeekChatRequest(
        model: settings.model.rawValue,
        messages: PromptBuilder().extractMemoryPrompt(rawEntry: rawEntry, knownPeople: knownPeople, knownThemes: knownThemes),
        responseFormat: .init(type: "json_object"),
        thinking: .init(type: settings.model.thinkingMode || settings.deepThinking ? "enabled" : "disabled"),
        reasoningEffort: settings.model.thinkingMode || settings.deepThinking ? "high" : nil,
        temperature: settings.model.thinkingMode || settings.deepThinking ? 0 : 0.1,
        maxTokens: 1800,
        stream: false
    )
}

private struct DeepSeekChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

public enum LocalAIError: LocalizedError {
    case invalidResponse
    case invalidTestResponse
    case invalidKey
    case rateLimited
    case timeout
    case networkUnavailable
    case network(String)
    case modelUnavailable(String)
    case httpStatus(Int, String)
    case emptyContent

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "DeepSeek returned an invalid response."
        case .invalidTestResponse:
            "DeepSeek responded, but the test payload was not valid JSON."
        case .invalidKey:
            "DeepSeek API key is invalid. Update it in Settings."
        case .rateLimited:
            "DeepSeek rate limit reached. Raw input is saved; retry later."
        case .timeout:
            "DeepSeek request timed out. Raw input is saved; retry later."
        case .networkUnavailable:
            "Network is unavailable. Raw input is saved locally."
        case .network(let message):
            "DeepSeek network request failed: \(message)"
        case .modelUnavailable(let model):
            "DeepSeek model \(model) is not available for this API key."
        case .httpStatus(let code, let message):
            message.isEmpty ? "DeepSeek request failed with status \(code)." : "DeepSeek request failed with status \(code): \(message)"
        case .emptyContent:
            "DeepSeek returned empty content."
        }
    }
}

private func summarizeExtraction(_ content: String, fallback: String) -> String {
    if let data = content.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let people = json["people"] as? [[String: Any]],
       let updates = people.first?["updates"] as? [[String: Any]],
       let summary = updates.first?["summary"] as? String,
       !summary.isEmpty {
        return summary
    }
    return fallback.count > 96 ? String(fallback.prefix(93)) + "..." : fallback
}

private func guessPersonName(from text: String) -> String {
    let words = text.split(whereSeparator: { !$0.isLetter })
    return words.first { word in
        guard let first = word.first else { return false }
        return first.isUppercase
    }.map(String.init) ?? "New friend"
}
