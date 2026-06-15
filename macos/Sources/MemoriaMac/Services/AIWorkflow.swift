import Foundation

public struct AIJSONParser: Sendable {
    public init() {}

    public func parseExtractMemoryResponse(data: Data) throws -> ExtractMemoryResponse {
        do {
            let decoded = try JSONDecoder().decode(ExtractMemoryResponse.self, from: data)
            try AIContractValidator().validate(decoded)
            return decoded
        } catch let error as AIContractError {
            throw error
        } catch {
            throw AIContractError.invalidJSON
        }
    }

    public func parseExtractMemoryResponse(content: String) throws -> ExtractMemoryResponse {
        guard let data = content.data(using: .utf8) else {
            throw AIContractError.invalidJSON
        }
        return try parseExtractMemoryResponse(data: data)
    }
}

public struct AIContractValidator: Sendable {
    public init() {}

    public func validate(_ response: ExtractMemoryResponse) throws {
        for proposal in response.memoryProposals {
            guard proposal.proposalType == .memoryAtom else {
                throw AIContractError.unsupportedProposalType(proposal.proposalType.rawValue)
            }
            guard !proposal.sourceQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIContractError.missingSourceQuote
            }
        }
        for proposal in response.personFactProposals {
            try validateProfilePatch(proposal)
        }
    }

    public func validateProfilePatch(_ proposal: PersonProfilePatchProposal) throws {
        guard !proposal.sourceQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIContractError.missingSourceQuote
        }
        guard proposal.targetPersonID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            !proposal.targetDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIContractError.invalidProfilePatch
        }
        guard !proposal.proposedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIContractError.invalidProfilePatch
        }
    }
}

public struct RouteInputResult: Codable, Equatable, Sendable {
    public let primaryType: String
    public let secondaryTypes: [String]
    public let confidence: Double
    public let requiresExtraction: Bool
    public let requiresPersonLinking: Bool
    public let requiresReminderGeneration: Bool
    public let requiresGiftGeneration: Bool
    public let language: String
    public let reasonSummary: String

    enum CodingKeys: String, CodingKey {
        case primaryType = "primary_type"
        case secondaryTypes = "secondary_types"
        case confidence
        case requiresExtraction = "requires_extraction"
        case requiresPersonLinking = "requires_person_linking"
        case requiresReminderGeneration = "requires_reminder_generation"
        case requiresGiftGeneration = "requires_gift_generation"
        case language
        case reasonSummary = "reason_summary"
    }
}

public struct PromptBuilder: Sendable {
    public init() {}

    public func routeInputPrompt(text: String) -> [DeepSeekChatRequest.Message] {
        [
            .init(
                role: "system",
                content: """
                You are Memoria's route_input workflow. Return strict json object only.
                Classify the user's free-form memory input without mutating data.
                """
            ),
            .init(role: "user", content: text)
        ]
    }

    public func extractMemoryPrompt(rawEntry: RawEntry, knownPeople: [FriendPerson], knownThemes: [Theme]) -> [DeepSeekChatRequest.Message] {
        let people = knownPeople.map { person in
            "{\"id\":\"\(person.id)\",\"display_name\":\"\(person.displayName)\",\"nickname\":\"\(person.nickname)\",\"aliases\":[\"\(person.englishName)\"],\"manual_closeness_level\":\(person.manualClosenessLevel)}"
        }.joined(separator: ",")
        let themes = knownThemes.map(\.name).joined(separator: ", ")
        let profileSchema = PersonProfileCategory.aiSchemaDescription
        return [
            .init(
                role: "system",
                content: """
                你是 Memoria 的个人记忆整理助手。你的任务是把用户的自由输入整理为结构化、可确认、可追溯的记忆建议。

                规则：
                1. 只抽取用户文本明确表达或强烈支持的信息。
                2. 不要编造事实。
                3. 每条记忆必须有 source_quote。
                4. 个人感悟、朋友事实、关系观察必须区分。
                5. 心理、健康、家庭、财务、恋爱、政治等内容标记 sensitive 或 private。
                6. 模糊表达必须降低 confidence。
                7. AI 推断必须设置 is_ai_inferred=true。
                8. 不要输出诊断，不要把反思写成心理疾病判断。
                9. 不要直接决定关系等级变化，只能提出建议。
                10. 输出严格 json object，不要 markdown，不要解释文字。
                11. 朋友档案字段必须归入 profile_category 之一，category key 只能来自下面 schema。
                12. AI 推断只能归入 ai_inference，必须标记为推断，不能写成确认事实。
                13. 如果原文明确支持两个人之间的关系边，只能放入 relationship_edge_proposals，且必须包含 source_quote；批准前不会写入关系星图。
                14. relationship_edge_proposals 不能表达亲近等级变化，不能修改 manual_closeness_level。
                15. relationship_edge_proposals 可以提供 tags 和 ai_primary_tag；tags 是自由关系标签，ai_primary_tag 只能从 tags 里选一个最能概括当前关系的标签。

                profile category schema:
                \(profileSchema)

                json example: {"entry_summary":"","memory_proposals":[{"proposal_type":"memory_atom","memory_type":"relationship_memory","title":"","summary":"","content":"","source_quote":"","confidence":0.8,"sensitivity":"normal","is_ai_inferred":false,"related_people":[],"themes":[],"relationship_edge_proposals":[{"source_person_id":"","source_display_name":"","target_person_id":"","target_display_name":"","label":"","strength":0.5,"relation_kind":"friend","tags":["同学"],"ai_primary_tag":"同学","confidence":0.8,"is_ai_inferred":true,"source_quote":""}],"follow_up_questions":[],"suggested_actions":[]}],"person_fact_proposals":[{"target_person_id":"","target_display_name":"","profile_category":"food_preference","proposed_value":"","source_quote":"","confidence":0.8,"sensitivity":"normal","is_ai_inferred":false,"merge_strategy":"append_unique"}],"reminder_proposals":[],"gift_signal_proposals":[],"conflicts":[],"follow_up_questions":[]}
                """
            ),
            .init(
                role: "user",
                content: """
                {"raw_entry_id":"\(rawEntry.id)","raw_text":"\(rawEntry.rawText)","known_people":[\(people)],"known_themes":"\(themes)"}
                """
            )
        ]
    }
}

public struct AIWorkflowService: Sendable {
    public typealias RemoteExtractMemory = @Sendable (
        RawEntry,
        [FriendPerson],
        [Theme],
        String,
        NativeSettings
    ) async throws -> ExtractMemoryResponse

    private let parser: AIJSONParser
    private let remoteExtractMemory: RemoteExtractMemory

    public init(
        parser: AIJSONParser = AIJSONParser(),
        deepSeek: DeepSeekClient = DeepSeekClient(),
        remoteExtractMemory: RemoteExtractMemory? = nil
    ) {
        self.parser = parser
        self.remoteExtractMemory = remoteExtractMemory ?? { rawEntry, knownPeople, knownThemes, apiKey, settings in
            try await deepSeek.extractMemory(
                rawEntry: rawEntry,
                knownPeople: knownPeople,
                knownThemes: knownThemes,
                apiKey: apiKey,
                settings: settings
            )
        }
    }

    public func routeInput(text: String) -> RouteInputResult {
        let mentionsKnownPerson = ["Alex", "May", "Jason"].contains { name in
            text.localizedCaseInsensitiveContains(name)
        }
        let primaryType = fallbackMemoryType(for: text, matchedPerson: mentionsKnownPerson ? DashboardSnapshot.demo.people.first : nil)

        return RouteInputResult(
            primaryType: primaryType.rawValue,
            secondaryTypes: mentionsKnownPerson && primaryType != .relationshipMemory ? ["relationship_memory"] : [],
            confidence: 0.78,
            requiresExtraction: true,
            requiresPersonLinking: mentionsKnownPerson,
            requiresReminderGeneration: text.contains("提醒"),
            requiresGiftGeneration: text.contains("礼物"),
            language: containsChinese(text) ? "zh" : "en",
            reasonSummary: "Local mocked route for deterministic macOS workflow tests."
        )
    }

    public func extractMemory(
        rawEntry: RawEntry,
        knownPeople: [FriendPerson],
        knownThemes: [Theme],
        apiKey: String?,
        settings: NativeSettings
    ) async throws -> ExtractMemoryResponse {
        if let apiKey, !apiKey.isEmpty {
            return try await remoteExtractMemory(rawEntry, knownPeople, knownThemes, apiKey, settings)
        }

        return try parser.parseExtractMemoryResponse(data: mockExtractMemoryData(for: rawEntry, knownPeople: knownPeople))
    }

    private func mockExtractMemoryData(for rawEntry: RawEntry, knownPeople: [FriendPerson]) throws -> Data {
        let text = rawEntry.rawText
        let matchedPerson = matchedPerson(in: text, knownPeople: knownPeople)
        let personName = matchedPerson?.displayName ?? "Memory"
        let memoryType = fallbackMemoryType(for: text, matchedPerson: matchedPerson)
        let sensitivity = fallbackSensitivity(for: text, memoryType: memoryType)
        let title = fallbackTitle(for: text, personName: personName, memoryType: memoryType)
        let proposal = MemoryAtomProposal(
            proposalType: .memoryAtom,
            memoryType: memoryType,
            title: title,
            summary: text.count > 96 ? String(text.prefix(93)) + "..." : text,
            content: text,
            sourceQuote: text,
            confidence: 0.86,
            sensitivity: sensitivity,
            isAIInferred: false,
            relatedPeople: matchedPerson.map { person in
                [
                    RelatedPersonProposal(
                        displayName: person.displayName,
                        matchedPersonID: person.id,
                        matchConfidence: 0.91,
                        relationType: "about"
                    )
                ]
            } ?? [],
            themes: fallbackThemes(for: text, memoryType: memoryType),
            followUpQuestions: [fallbackFollowUpQuestion(for: personName, memoryType: memoryType)],
            suggestedActions: []
        )
        let personFactProposals = fallbackProfilePatches(for: text, matchedPerson: matchedPerson)
        let response = ExtractMemoryResponse(
            entrySummary: proposal.summary,
            memoryProposals: [proposal],
            personFactProposals: personFactProposals,
            reminderProposals: [],
            giftSignalProposals: [],
            conflicts: [],
            followUpQuestions: proposal.followUpQuestions
        )
        return try JSONEncoder().encode(response)
    }
}

private func matchedPerson(in text: String, knownPeople: [FriendPerson]) -> FriendPerson? {
    knownPeople.first { person in
        person.matchAliases.contains { alias in
            text.localizedCaseInsensitiveContains(alias)
        }
    }
}

private func fallbackMemoryType(for text: String, matchedPerson: FriendPerson?) -> MemoryAtomType {
    if containsAny(["礼物", "gift", "present"], in: text) {
        return .giftSignal
    }

    if containsAny(["提醒", "别忘", "remind", "deadline", "due"], in: text) {
        return .reminderSource
    }

    if matchedPerson != nil, looksLikeFriendFact(text) {
        return .personFact
    }

    if matchedPerson != nil, containsAny(["关系", "共同朋友", "室友", "同学", "伴侣", "男朋友", "女朋友", "partner", "roommate", "classmate"], in: text) {
        return .relationshipMemory
    }

    return .personalReflection
}

private func fallbackSensitivity(for text: String, memoryType: MemoryAtomType) -> MemorySensitivity {
    if containsAny(["家庭", "财务", "恋爱", "政治", "健康", "病", "抑郁", "焦虑", "family", "finance", "health"], in: text) {
        return .sensitive
    }

    return memoryType == .personalReflection ? .private : .normal
}

private func fallbackTitle(for text: String, personName: String, memoryType: MemoryAtomType) -> String {
    switch memoryType {
    case .giftSignal:
        return personName == "Memory" ? "礼物线索" : "\(personName) 的礼物线索"
    case .reminderSource:
        return "从记录中提取的提醒线索"
    case .personFact:
        return "\(personName) 的朋友事实：\(compactFactText(text))"
    case .relationshipMemory:
        return personName == "Memory" ? "关系观察" : "\(personName) 的关系观察"
    case .personalReflection:
        if containsAny(["怕麻烦", "害怕麻烦"], in: text) {
            return "我在人际关系里害怕麻烦别人"
        }
        return "个人想法：\(compactFactText(text))"
    default:
        return compactFactText(text)
    }
}

private func fallbackThemes(for text: String, memoryType: MemoryAtomType) -> [ThemeProposal] {
    switch memoryType {
    case .personFact:
        if containsAny(["吃", "喝", "忌口", "过敏", "food", "drink"], in: text) {
            return [
                ThemeProposal(name: "饮食偏好", confidence: 0.9),
                ThemeProposal(name: "朋友事实", confidence: 0.84)
            ]
        }
        return [ThemeProposal(name: "朋友事实", confidence: 0.88)]
    case .giftSignal:
        return [ThemeProposal(name: "礼物线索", confidence: 0.9)]
    case .reminderSource:
        return [ThemeProposal(name: "提醒事项", confidence: 0.86)]
    case .relationshipMemory:
        return [ThemeProposal(name: "关系观察", confidence: 0.86)]
    default:
        return [
            ThemeProposal(name: "自我表达", confidence: 0.9),
            ThemeProposal(name: "关系边界", confidence: 0.82)
        ]
    }
}

private func fallbackProfilePatches(for text: String, matchedPerson: FriendPerson?) -> [PersonProfilePatchProposal] {
    guard let matchedPerson else { return [] }

    var patches: [PersonProfilePatchProposal] = []
    let factText = compactFactText(text)
    if containsAny(["喜欢", "爱吃", "爱喝", "火锅", "咖啡", "food", "drink", "likes"], in: text) {
        patches.append(
            PersonProfilePatchProposal(
                targetPersonID: matchedPerson.id,
                targetDisplayName: matchedPerson.displayName,
                profileCategory: .foodPreference,
                proposedValue: profilePatchValue(
                    in: text,
                    matchedPerson: matchedPerson,
                    keywords: ["喜欢", "爱吃", "爱喝", "火锅", "咖啡", "food", "drink", "likes"]
                ) ?? factText,
                sourceQuote: text,
                confidence: 0.88,
                sensitivity: .normal,
                isAIInferred: false
            )
        )
    }

    if containsAny(["不吃", "忌口", "过敏", "allergy", "does not eat"], in: text) {
        patches.append(
            PersonProfilePatchProposal(
                targetPersonID: matchedPerson.id,
                targetDisplayName: matchedPerson.displayName,
                profileCategory: .dietaryAllergy,
                proposedValue: profilePatchValue(
                    in: text,
                    matchedPerson: matchedPerson,
                    keywords: ["不吃", "忌口", "过敏", "allergy", "does not eat"]
                ) ?? factText,
                sourceQuote: text,
                confidence: 0.9,
                sensitivity: .normal,
                isAIInferred: false
            )
        )
    }

    if containsAny(["生日", "birthday"], in: text) {
        patches.append(
            PersonProfilePatchProposal(
                targetPersonID: matchedPerson.id,
                targetDisplayName: matchedPerson.displayName,
                profileCategory: .anniversaries,
                proposedValue: profilePatchValue(
                    in: text,
                    matchedPerson: matchedPerson,
                    keywords: ["生日", "birthday"]
                ) ?? factText,
                sourceQuote: text,
                confidence: 0.84,
                sensitivity: .normal,
                isAIInferred: false
            )
        )
    }

    if containsAny(["最近在学", "喜欢讨论", "兴趣", "interests"], in: text) {
        patches.append(
            PersonProfilePatchProposal(
                targetPersonID: matchedPerson.id,
                targetDisplayName: matchedPerson.displayName,
                profileCategory: .interests,
                proposedValue: profilePatchValue(
                    in: text,
                    matchedPerson: matchedPerson,
                    keywords: ["最近在学", "喜欢讨论", "兴趣", "interests"]
                ) ?? factText,
                sourceQuote: text,
                confidence: 0.8,
                sensitivity: .normal,
                isAIInferred: false
            )
        )
    }

    return patches
}

private func profilePatchValue(
    in text: String,
    matchedPerson: FriendPerson,
    keywords: [String]
) -> String? {
    let segments = text
        .components(separatedBy: CharacterSet(charactersIn: "，,。.;；\n"))
        .map { cleanProfilePatchSegment($0, matchedPerson: matchedPerson) }
        .filter { !$0.isEmpty }

    return segments.first { segment in
        containsAny(keywords, in: segment)
    }
}

private func cleanProfilePatchSegment(_ segment: String, matchedPerson: FriendPerson) -> String {
    var cleaned = segment.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    for removable in ["我记得", matchedPerson.displayName, matchedPerson.nickname, matchedPerson.englishName] where !removable.isEmpty {
        cleaned = cleaned.replacingOccurrences(of: removable, with: "", options: [.caseInsensitive])
    }
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
}

private func fallbackFollowUpQuestion(for personName: String, memoryType: MemoryAtomType) -> String {
    switch memoryType {
    case .personFact:
        return personName == "Memory" ? "要不要把这条事实保存到朋友档案？" : "要不要把这条事实更新到 \(personName) 的朋友档案？"
    case .giftSignal:
        return personName == "Memory" ? "要不要保存这条礼物线索？" : "要不要把这条礼物线索关联到 \(personName)？"
    case .reminderSource:
        return "要不要基于这条记录创建提醒？"
    default:
        return personName == "Memory" ? "要不要保存这条记忆？" : "要不要把这条记忆关联到 \(personName) 的关系时间线？"
    }
}

private func looksLikeFriendFact(_ text: String) -> Bool {
    containsAny(
        [
            "喜欢", "爱吃", "爱喝", "不吃", "不喜欢", "讨厌", "忌口", "过敏",
            "生日", "住在", "来自", "家乡", "学校", "专业", "公司", "实习",
            "工作", "微信", "电话", "mbti", "星座", "计划", "最近在学",
            "likes", "dislikes", "birthday", "allergy", "school", "major", "works at"
        ],
        in: text
    )
}

private func containsAny(_ needles: [String], in text: String) -> Bool {
    needles.contains { text.localizedCaseInsensitiveContains($0) }
}

private func compactFactText(_ text: String) -> String {
    let trimmed = text
        .replacingOccurrences(of: "我记得", with: "")
        .replacingOccurrences(of: "我记得，", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    guard trimmed.count > 42 else { return trimmed }
    return String(trimmed.prefix(39)) + "..."
}

private extension FriendPerson {
    var matchAliases: [String] {
        [
            displayName,
            nickname,
            englishName,
            displayName.split(separator: " ").first.map(String.init) ?? ""
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    }
}

public struct GiftRecommendationWorkflow: Sendable {
    public init() {}

    public func recommendations(for person: FriendPerson, prompt: String) -> [GiftIdea] {
        let budget = parseBudget(from: prompt) ?? "300-500 元"
        let combinedSignals = [
            person.interests,
            person.categoryNote(.interests),
            person.categoryNote(.travelPreference),
            person.categoryNote(.currentState),
            person.categoryNote(.giftHistory),
            person.categoryNote(.spendingPreference)
        ].joined(separator: "\n")

        var ideas: [GiftIdea] = []
        if combinedSignals.contains("陶艺") || prompt.contains("心意") {
            ideas.append(
                GiftIdea(
                    id: "gift-\(person.id)-ceramic-\(stablePromptSuffix(prompt))",
                    title: "推荐方向 1：陶艺相关体验或工具",
                    personName: person.displayName,
                    priceBand: budget,
                    rationale: "她最近在学陶艺，体验型礼物比单纯物品更贴合当前兴趣。",
                    risk: "如果她已经有固定课程，重复购买可能浪费。",
                    confirmationQuestion: "她是手作体验型还是想长期学习？",
                    matchScore: 92,
                    surpriseScore: 82,
                    riskLevel: "中",
                    practicality: "中",
                    emotionalValue: "高",
                    needsMoreInfo: true
                )
            )
        }

        if combinedSignals.contains("冰岛") || combinedSignals.contains("旅行") || prompt.contains("旅行") {
            ideas.append(
                GiftIdea(
                    id: "gift-\(person.id)-iceland-\(stablePromptSuffix(prompt))",
                    title: "推荐方向 2：冰岛旅行相关实用物品",
                    personName: person.displayName,
                    priceBand: budget,
                    rationale: "她 8 月要去冰岛，可以送轻便保暖、旅行收纳、拍照相关物品。",
                    risk: "功能性礼物如果审美不合，惊喜感不足。",
                    confirmationQuestion: "她已经买了哪些旅行装备？她偏什么颜色？",
                    matchScore: 86,
                    surpriseScore: 70,
                    riskLevel: "中",
                    practicality: "高",
                    emotionalValue: "中",
                    needsMoreInfo: true
                )
            )
        }

        ideas.append(
            GiftIdea(
                id: "gift-\(person.id)-support-\(stablePromptSuffix(prompt))",
                title: "推荐方向 3：换工作阶段的低压力陪伴礼物",
                personName: person.displayName,
                priceBand: budget,
                rationale: "她最近压力较大，适合送香薰、按摩、睡眠、轻办公相关物品。",
                risk: "不要显得像在暗示她状态不好。",
                confirmationQuestion: "她最近更需要放松、效率，还是有人陪她聊聊？",
                matchScore: 84,
                surpriseScore: 76,
                riskLevel: "低",
                practicality: "高",
                emotionalValue: "高",
                needsMoreInfo: false
            )
        )

        while ideas.count < 3 {
            ideas.append(
                GiftIdea(
                    id: "gift-\(person.id)-ritual-\(ideas.count)-\(stablePromptSuffix(prompt))",
                    title: "推荐方向 \(ideas.count + 1)：有仪式感的小众日常礼物",
                    personName: person.displayName,
                    priceBand: budget,
                    rationale: "她更重视心意和被理解的感觉，小众但贴合日常的礼物比标准爆款更合适。",
                    risk: "审美偏好不确认时容易买到不合适的颜色或香味。",
                    confirmationQuestion: "她最近更偏哪种颜色、香味或日常使用场景？",
                    matchScore: 78,
                    surpriseScore: 72,
                    riskLevel: "中",
                    practicality: "中",
                    emotionalValue: "高",
                    needsMoreInfo: true
                )
            )
        }

        return Array(ideas.prefix(3))
    }
}

private func containsChinese(_ text: String) -> Bool {
    text.unicodeScalars.contains { scalar in
        scalar.value >= 0x4E00 && scalar.value <= 0x9FFF
    }
}

private func parseBudget(from prompt: String) -> String? {
    let digits = prompt.split { !$0.isNumber }.compactMap { Int($0) }
    guard digits.count >= 2 else { return nil }
    return "\(digits[0])-\(digits[1]) 元"
}

private func stablePromptSuffix(_ prompt: String) -> String {
    let value = abs(prompt.unicodeScalars.reduce(0) { partialResult, scalar in
        partialResult &* 31 &+ Int(scalar.value)
    })
    return String(value % 100_000)
}
