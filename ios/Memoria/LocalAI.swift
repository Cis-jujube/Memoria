import Foundation

enum DeepSeekModel: String, CaseIterable, Identifiable {
    case flash = "deepseek-v4-flash"
    case pro = "deepseek-v4-pro"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flash:
            "Flash"
        case .pro:
            "Pro"
        }
    }
}

enum LanguagePreference: String, CaseIterable, Identifiable {
    case system
    case zhCN = "zh-CN"
    case en

    var id: String { rawValue }
}

struct NativeCopy {
    let aiInboxTitle: String
    let whySuggested: String
    let settingsTitle: String
    let deepSeekSectionTitle: String
    let apiKeyPlaceholder: String
    let saveKey: String
    let testConnection: String
    let removeKey: String
    let modelLabel: String
    let deepThinkingLabel: String
    let languageLabel: String
    let deepseekPrivacyNote: String
    let missingKeyMessage: String
    let quickCaptureTitle: String
    let quickCapturePlaceholder: String
    let sendToInbox: String
}

extension NativeCopy {
    static let english = NativeCopy(
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
        quickCaptureTitle: "Quick Capture",
        quickCapturePlaceholder: "Type a memory, plan, preference, or reminder...",
        sendToInbox: "Send to AI Inbox"
    )

    static let zhCN = NativeCopy(
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
        quickCaptureTitle: "快速记录",
        quickCapturePlaceholder: "写下一段记忆、偏好、计划，或者需要提醒的事...",
        sendToInbox: "发送到待确认"
    )
}

struct NativeSettings: Equatable {
    var model: DeepSeekModel = .flash
    var deepThinking = false
    var language: LanguagePreference = .system
    var hasAPIKey = false
}

func nativeCopy(for language: LanguagePreference) -> NativeCopy {
    switch resolvedLanguage(language) {
    case .zhCN:
        .zhCN
    case .en, .system:
        .english
    }
}

func resolvedLanguage(_ language: LanguagePreference) -> LanguagePreference {
    if language != .system {
        return language
    }

    let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
    return preferred.hasPrefix("zh") ? .zhCN : .en
}

struct DeepSeekChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable {
        let type: String
    }

    struct Thinking: Encodable {
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

func makeDeepSeekRequest(
    text: String,
    model: DeepSeekModel,
    deepThinking: Bool,
    locale: String,
    timezone: String
) -> DeepSeekChatRequest {
    let systemPrompt = """
    Extract friend relationship facts from student-life notes. Keep sensitive facts minimal, evidence-backed, and ready for human review before saving.
    Return only valid JSON. Do not include markdown or prose.
    The JSON object must use this exact top-level shape:
    {"people":[],"reminders":[],"giftIdeas":[]}
    """

    return DeepSeekChatRequest(
        model: model.rawValue,
        messages: [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: "Locale: \(locale)\nTimezone: \(timezone)\nNote:\n\(text)")
        ],
        responseFormat: .init(type: "json_object"),
        thinking: .init(type: deepThinking ? "enabled" : "disabled"),
        reasoningEffort: deepThinking ? "high" : nil,
        temperature: 0.1,
        maxTokens: 1600,
        stream: false
    )
}

struct DeepSeekClient {
    func testConnection(apiKey: String, settings: NativeSettings) async throws {
        _ = try await extract(text: "Alex likes hotpot.", apiKey: apiKey, settings: settings)
    }

    func extract(text: String, apiKey: String, settings: NativeSettings) async throws -> PendingUpdate {
        let request = makeDeepSeekRequest(
            text: text,
            model: settings.model,
            deepThinking: settings.deepThinking,
            locale: resolvedLanguage(settings.language).rawValue,
            timezone: TimeZone.current.identifier
        )

        var urlRequest = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocalAIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LocalAIError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalAIError.emptyContent
        }

        return PendingUpdate(
            id: "ai-\(UUID().uuidString)",
            type: "AI",
            summary: summarizeExtraction(content, fallback: text),
            evidence: text,
            personName: guessPersonName(from: text),
            createdLabel: Date.now.formatted(date: .omitted, time: .shortened)
        )
    }
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

enum LocalAIError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "DeepSeek returned an invalid response."
        case .httpStatus(let code):
            "DeepSeek request failed with status \(code)."
        case .emptyContent:
            "DeepSeek returned empty content."
        }
    }
}

private func summarizeExtraction(_ content: String, fallback: String) -> String {
    if let data = content.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let people = json["people"] as? [[String: Any]],
       let firstUpdate = people.first?["updates"] as? [[String: Any]],
       let summary = firstUpdate.first?["summary"] as? String,
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
