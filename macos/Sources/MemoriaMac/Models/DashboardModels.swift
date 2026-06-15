import Foundation
import SwiftUI

public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case home
    case capture
    case aiReview
    case selfSearch
    case memory
    case friendDossier
    case people
    case relationshipMap
    case schedule
    case actions
    case ask
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home:
            "Home"
        case .capture:
            "Capture"
        case .aiReview:
            "AI Review"
        case .selfSearch:
            "Self Search"
        case .memory:
            "Self Index"
        case .friendDossier:
            "Friend Dossier Management"
        case .people:
            "People"
        case .relationshipMap:
            "Relationship Map"
        case .schedule:
            "Schedule"
        case .actions:
            "Actions"
        case .ask:
            "Ask"
        case .settings:
            "Settings"
        }
    }

    public func title(for language: LanguagePreference) -> String {
        guard resolvedLanguage(language) == .zhCN else {
            return title
        }

        switch self {
        case .home:
            return "首页"
        case .capture:
            return "记录"
        case .aiReview:
            return "整理台"
        case .selfSearch:
            return "自我检索"
        case .memory:
            return "自我检索"
        case .friendDossier:
            return "朋友档案管理"
        case .people:
            return "朋友档案管理"
        case .relationshipMap:
            return "关系星图"
        case .schedule:
            return "行程安排"
        case .actions:
            return "行程安排"
        case .ask:
            return "对话检索"
        case .settings:
            return "设置"
        }
    }

    public var systemImage: String {
        switch self {
        case .home:
            "rectangle.grid.2x2"
        case .capture:
            "square.and.pencil"
        case .aiReview:
            "tray"
        case .selfSearch:
            "magnifyingglass.circle"
        case .memory:
            "archivebox"
        case .friendDossier:
            "person.text.rectangle"
        case .people:
            "person.2"
        case .relationshipMap:
            "point.3.connected.trianglepath.dotted"
        case .schedule:
            "calendar"
        case .actions:
            "checklist"
        case .ask:
            "bubble.left.and.text.bubble.right"
        case .settings:
            "gearshape"
        }
    }
}

public enum WorkspaceMode: String, CaseIterable, Identifiable, Sendable {
    case selfSearch
    case friendDossier
    case schedule

    public var id: String { rawValue }

    public func title(for language: LanguagePreference) -> String {
        guard resolvedLanguage(language) == .zhCN else {
            switch self {
            case .selfSearch:
                return "Self Search"
            case .friendDossier:
                return "Friend Dossier Management"
            case .schedule:
                return "Schedule"
            }
        }

        switch self {
        case .selfSearch:
            return "自我检索"
        case .friendDossier:
            return "朋友档案管理"
        case .schedule:
            return "行程安排"
        }
    }

    public func subtitle(for language: LanguagePreference) -> String {
        guard resolvedLanguage(language) == .zhCN else {
            switch self {
            case .selfSearch:
                return "Search confirmed reflections through core tags and personal context."
            case .friendDossier:
                return "Read quiet friend dossiers and let approved memory shape the two-hop map."
            case .schedule:
                return "Plan reminders, birthdays, exams, meetings, and preparation across week and month views."
            }
        }

        switch self {
        case .selfSearch:
            return "用核心标签检索确认后的感悟、选择、压力和成长线索。"
        case .friendDossier:
            return "查看朋友档案、确认记忆和两层关系星图。"
        case .schedule:
            return "按周和月管理提醒、生日、考试、约见和准备事项。"
        }
    }

    public var systemImage: String {
        switch self {
        case .selfSearch:
            return "magnifyingglass.circle"
        case .friendDossier:
            return "person.text.rectangle"
        case .schedule:
            return "calendar"
        }
    }

    public var primarySection: AppSection {
        switch self {
        case .selfSearch:
            return .selfSearch
        case .friendDossier:
            return .friendDossier
        case .schedule:
            return .schedule
        }
    }

    public var reviewCategory: ReviewCategory {
        switch self {
        case .selfSearch:
            return .selfSearch
        case .friendDossier:
            return .friendDossier
        case .schedule:
            return .schedule
        }
    }
}

public struct SelfIndexThemePreset: Identifiable, Equatable, Sendable {
    public let name: String
    public let description: String

    public var id: String { name }
}

public struct SelfIndexThemeSummary: Identifiable, Equatable, Sendable {
    public let theme: Theme
    public let memoryCount: Int

    public var id: String { theme.id }
}

public extension MemoryAtom {
    var isSelfSearchDefault: Bool {
        type == .personalReflection || type == .idea || type == .fileNote
    }
}

public let defaultSelfIndexThemePresets: [SelfIndexThemePreset] = [
    SelfIndexThemePreset(name: "自我认知", description: "关于自我理解、性格、习惯和长期模式的反思。"),
    SelfIndexThemePreset(name: "情绪状态", description: "关于情绪波动、触发点和当下感受的记录。"),
    SelfIndexThemePreset(name: "关系边界", description: "关于边界、压力、拒绝、期待和相处方式的判断。"),
    SelfIndexThemePreset(name: "亲密/朋友", description: "关于亲密关系、友情、陪伴和信任变化的观察。"),
    SelfIndexThemePreset(name: "学业成长", description: "关于课程、学习策略、考试和知识成长的复盘。"),
    SelfIndexThemePreset(name: "职业方向", description: "关于实习、研究、职业选择和能力建设的线索。"),
    SelfIndexThemePreset(name: "创作灵感", description: "关于想法、作品、表达欲和可发展主题的记录。"),
    SelfIndexThemePreset(name: "身体作息", description: "关于睡眠、饮食、运动和身体状态的记录。"),
    SelfIndexThemePreset(name: "压力恢复", description: "关于压力来源、恢复方式和支持系统的复盘。"),
    SelfIndexThemePreset(name: "价值判断", description: "关于取舍、原则、偏好和判断标准的记录。"),
    SelfIndexThemePreset(name: "重要选择", description: "关于关键决定、备选路径和后续影响的记录。"),
    SelfIndexThemePreset(name: "生活审美", description: "关于喜欢的空间、物品、风格、城市和生活质感。")
]

public struct RelationshipTagPriority: Identifiable, Equatable, Sendable {
    public let tag: String
    public let rank: Int
    public let updatedAt: String

    public var id: String { tag }

    public init(tag: String, rank: Int, updatedAt: String = memoriaTimestamp()) {
        self.tag = tag
        self.rank = rank
        self.updatedAt = updatedAt
    }
}

public let defaultRelationshipTagPriorities: [RelationshipTagPriority] = [
    RelationshipTagPriority(tag: "恋人", rank: 10),
    RelationshipTagPriority(tag: "伴侣", rank: 11),
    RelationshipTagPriority(tag: "家人", rank: 20),
    RelationshipTagPriority(tag: "核心朋友", rank: 30),
    RelationshipTagPriority(tag: "好朋友", rank: 40),
    RelationshipTagPriority(tag: "室友", rank: 50),
    RelationshipTagPriority(tag: "哥们", rank: 60),
    RelationshipTagPriority(tag: "同学", rank: 70),
    RelationshipTagPriority(tag: "项目伙伴", rank: 80),
    RelationshipTagPriority(tag: "同事", rank: 90),
    RelationshipTagPriority(tag: "导师", rank: 100),
    RelationshipTagPriority(tag: "弱连接", rank: 200)
]

public enum GroupFilter: String, CaseIterable, Identifiable, Sendable {
    case classmates = "Classmates"
    case studyAbroad = "Study Abroad"
    case homeFriends = "Home Friends"
    case internship = "Internship"

    public var id: String { rawValue }

    public func title(for language: LanguagePreference) -> String {
        guard resolvedLanguage(language) == .zhCN else {
            return rawValue
        }

        switch self {
        case .classmates:
            return "同学"
        case .studyAbroad:
            return "交换/海外"
        case .homeFriends:
            return "老朋友"
        case .internship:
            return "实习/职业"
        }
    }
}

public enum SidebarSelection: Hashable, Sendable {
    case section(AppSection)
    case group(GroupFilter)
}

public struct SidebarNavigationGroup: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let sections: [AppSection]

    public init(id: String, title: String, sections: [AppSection]) {
        self.id = id
        self.title = title
        self.sections = sections
    }
}

public func memoriaSidebarNavigationGroups(for language: LanguagePreference) -> [SidebarNavigationGroup] {
    let isChinese = resolvedLanguage(language) == .zhCN

    return [
        SidebarNavigationGroup(
            id: "overview",
            title: isChinese ? "总览" : "Overview",
            sections: [.home]
        ),
        SidebarNavigationGroup(
            id: "workflow",
            title: isChinese ? "工作流" : "Workflow",
            sections: [.capture, .aiReview]
        ),
        SidebarNavigationGroup(
            id: "modes",
            title: isChinese ? "三种模式" : "Modes",
            sections: [.selfSearch, .friendDossier, .schedule]
        ),
        SidebarNavigationGroup(
            id: "system",
            title: isChinese ? "系统" : "System",
            sections: [.settings]
        )
    ]
}

public enum ReviewCategory: String, CaseIterable, Identifiable, Sendable {
    case selfSearch
    case friendDossier
    case schedule

    public var id: String { rawValue }

    public func title(for language: LanguagePreference) -> String {
        guard resolvedLanguage(language) == .zhCN else {
            switch self {
            case .selfSearch:
                return "Self Search"
            case .friendDossier:
                return "Friend Dossier Management"
            case .schedule:
                return "Schedule"
            }
        }

        switch self {
        case .selfSearch:
            return "自我检索"
        case .friendDossier:
            return "朋友档案管理"
        case .schedule:
            return "行程安排"
        }
    }

    public var systemImage: String {
        switch self {
        case .selfSearch:
            return "magnifyingglass.circle"
        case .friendDossier:
            return "person.text.rectangle"
        case .schedule:
            return "calendar"
        }
    }

    public static func inferred(from proposal: MemoryAtomProposal?) -> ReviewCategory {
        guard let proposal else { return .selfSearch }
        switch proposal.memoryType {
        case .personalReflection, .idea, .fileNote:
            return .selfSearch
        case .relationshipMemory, .personFact, .giftSignal:
            return .friendDossier
        case .reminderSource:
            return .schedule
        case .event:
            return proposal.hasScheduleSignals ? .schedule : .selfSearch
        }
    }
}

public enum FocusPriority: String, Sendable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    public var color: Color {
        switch self {
        case .high:
            .orange
        case .medium:
            .green
        case .low:
            .secondary
        }
    }
}

public enum PersonProfileCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case identity = "identity"
    case contact = "contact"
    case relationship = "relationship"
    case education = "education"
    case career = "career"
    case family = "family"
    case friendNetwork = "friend_network"
    case interests = "interests"
    case media = "media"
    case foodPreference = "food_preference"
    case dietaryAllergy = "dietary_allergy"
    case travelPreference = "travel_preference"
    case styleAesthetic = "style_aesthetic"
    case spendingPreference = "spending_preference"
    case giftHistory = "gift_history"
    case lifestyle = "lifestyle"
    case currentState = "current_state"
    case lifeEvents = "life_events"
    case emotionalPreference = "emotional_preference"
    case communicationPreference = "communication_preference"
    case tabooBoundary = "taboo_boundary"
    case anniversaries = "anniversaries"
    case reminders = "reminders"
    case files = "files"
    case aiInference = "ai_inference"

    public var id: String { rawValue }

    public func title(for language: LanguagePreference) -> String {
        guard resolvedLanguage(language) == .zhCN else {
            return englishTitle
        }

        switch self {
        case .identity:
            return "身份信息"
        case .contact:
            return "联系方式"
        case .relationship:
            return "关系信息"
        case .education:
            return "教育经历"
        case .career:
            return "职业经历"
        case .family:
            return "家庭关系"
        case .friendNetwork:
            return "朋友网络"
        case .interests:
            return "兴趣爱好"
        case .media:
            return "书影音"
        case .foodPreference:
            return "饮食偏好"
        case .dietaryAllergy:
            return "忌口过敏"
        case .travelPreference:
            return "旅行偏好"
        case .styleAesthetic:
            return "穿搭审美"
        case .spendingPreference:
            return "消费偏好"
        case .giftHistory:
            return "礼物历史"
        case .lifestyle:
            return "生活习惯"
        case .currentState:
            return "当前状态"
        case .lifeEvents:
            return "人生大事"
        case .emotionalPreference:
            return "情绪偏好"
        case .communicationPreference:
            return "沟通偏好"
        case .tabooBoundary:
            return "禁区边界"
        case .anniversaries:
            return "纪念日"
        case .reminders:
            return "提醒事项"
        case .files:
            return "文件资料"
        case .aiInference:
            return "AI 推断"
        }
    }

    public var englishTitle: String {
        switch self {
        case .identity:
            return "Identity"
        case .contact:
            return "Contact"
        case .relationship:
            return "Relationship"
        case .education:
            return "Education"
        case .career:
            return "Career"
        case .family:
            return "Family"
        case .friendNetwork:
            return "Friend Network"
        case .interests:
            return "Interests"
        case .media:
            return "Books & Media"
        case .foodPreference:
            return "Food Preference"
        case .dietaryAllergy:
            return "Dietary & Allergy"
        case .travelPreference:
            return "Travel Preference"
        case .styleAesthetic:
            return "Style Aesthetic"
        case .spendingPreference:
            return "Spending Preference"
        case .giftHistory:
            return "Gift History"
        case .lifestyle:
            return "Lifestyle"
        case .currentState:
            return "Current State"
        case .lifeEvents:
            return "Life Events"
        case .emotionalPreference:
            return "Emotional Preference"
        case .communicationPreference:
            return "Communication Preference"
        case .tabooBoundary:
            return "Taboo & Boundary"
        case .anniversaries:
            return "Anniversaries"
        case .reminders:
            return "Reminders"
        case .files:
            return "Files"
        case .aiInference:
            return "AI Inference"
        }
    }

    public var fieldExamples: String {
        switch self {
        case .identity:
            return "姓名、昵称、英文名、头像、生日、年龄段、星座、MBTI、城市、家乡、语言"
        case .contact:
            return "微信、电话、邮箱、Instagram、小红书、LinkedIn、常用联系渠道"
        case .relationship:
            return "认识时间、认识地点、认识方式、共同朋友、亲近等级、关系标签、边界"
        case .education:
            return "学校、专业、年级、课程、导师、社团、交换经历、毕业时间"
        case .career:
            return "公司、岗位、行业、实习、项目、求职方向、简历、面试、职业目标"
        case .family:
            return "父母、兄弟姐妹、伴侣、宠物、家庭城市、重要家庭事件"
        case .friendNetwork:
            return "共同好友、朋友圈层、和谁关系好、和谁有矛盾、社交偏好"
        case .interests:
            return "阅读、电影、剧集、音乐、运动、游戏、手工、摄影、艺术、博物馆"
        case .media:
            return "喜欢的书、正在读的书、喜欢的作者、电影导演、歌手、播客、YouTube 频道"
        case .foodPreference:
            return "喜欢的菜系、餐厅、饮料、咖啡、茶、甜品、辣度、酒精偏好"
        case .dietaryAllergy:
            return "不吃什么、过敏源、宗教饮食限制、健康饮食要求"
        case .travelPreference:
            return "想去城市、去过城市、旅行方式、预算、酒店偏好、喜欢自然还是城市"
        case .styleAesthetic:
            return "喜欢颜色、品牌、风格、尺码、首饰偏好、香水偏好"
        case .spendingPreference:
            return "喜欢实用礼物还是仪式感礼物、喜欢大牌还是小众、介意二手吗"
        case .giftHistory:
            return "你送过什么、对方反应、别人送过什么、踩雷记录、愿望清单"
        case .lifestyle:
            return "作息、运动、睡眠、通勤、居住状态、是否养宠物、是否做饭"
        case .currentState:
            return "最近压力、最近开心的事、最近烦恼、近期目标、正在准备的事情"
        case .lifeEvents:
            return "升学、毕业、搬家、换工作、分手、恋爱、结婚、比赛、旅行、手术、考试"
        case .emotionalPreference:
            return "喜欢被怎么安慰、讨厌什么安慰方式、是否喜欢惊喜、是否需要空间"
        case .communicationPreference:
            return "喜欢文字还是语音、回复频率、是否讨厌电话、适合深聊还是轻松聊天"
        case .tabooBoundary:
            return "不该提的话题、不喜欢的玩笑、不想被评价的事情、隐私边界"
        case .anniversaries:
            return "生日、认识纪念日、毕业日、重要考试、工作入职日、宠物生日"
        case .reminders:
            return "生日礼物、问候、考试祝福、旅行前提醒、面试前鼓励、术后关心"
        case .files:
            return "简历、作品集、聊天截图、照片、PDF、语音转写、手写备注"
        case .aiInference:
            return "可能喜欢的风格、可能适合的礼物、可能的关系变化，但必须标记为推断"
        }
    }

    public static var aiSchemaDescription: String {
        allCases
            .map { "\($0.rawValue): \($0.fieldExamples)" }
            .joined(separator: "\n")
    }
}

public struct FriendPerson: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let nickname: String
    public let englishName: String
    public let relationLabel: String
    public let groupLabel: GroupFilter
    public let groupLabels: [GroupFilter]
    public let location: String
    public let hometown: String
    public let languages: String
    public let contactInfo: String
    public let birthday: String
    public let dietaryRestrictions: String
    public let favoriteFoods: String
    public let dislikedThings: String
    public let zodiacSign: String
    public let mbti: String
    public let interests: String
    public let books: String
    public let sports: String
    public let profileTags: String
    public let lastSignal: String
    public let initials: String
    public let school: String
    public let major: String
    public let company: String
    public let roleTitle: String
    public let researchExperience: String
    public let internshipExperience: String
    public let familyNotes: String
    public let partnerName: String
    public let manualClosenessLevel: Int
    public let closenessSignals: String
    public let categoryNotes: [PersonProfileCategory: String]

    public init(
        id: String,
        displayName: String,
        nickname: String = "",
        englishName: String = "",
        relationLabel: String,
        groupLabel: GroupFilter,
        groupLabels: [GroupFilter]? = nil,
        location: String,
        hometown: String = "",
        languages: String = "",
        contactInfo: String = "",
        birthday: String,
        dietaryRestrictions: String,
        favoriteFoods: String,
        dislikedThings: String,
        zodiacSign: String,
        mbti: String,
        interests: String,
        books: String,
        sports: String,
        profileTags: String,
        lastSignal: String,
        initials: String,
        school: String = "",
        major: String = "",
        company: String = "",
        roleTitle: String = "",
        researchExperience: String = "",
        internshipExperience: String = "",
        familyNotes: String = "",
        partnerName: String = "",
        manualClosenessLevel: Int = 3,
        closenessSignals: String = "",
        categoryNotes: [PersonProfileCategory: String] = [:]
    ) {
        self.id = id
        self.displayName = displayName
        self.nickname = nickname
        self.englishName = englishName
        self.relationLabel = relationLabel
        self.groupLabel = groupLabel
        self.groupLabels = Self.normalizedGroups(groupLabels ?? [groupLabel], fallback: groupLabel)
        self.location = location
        self.hometown = hometown
        self.languages = languages
        self.contactInfo = contactInfo
        self.birthday = birthday
        self.dietaryRestrictions = dietaryRestrictions
        self.favoriteFoods = favoriteFoods
        self.dislikedThings = dislikedThings
        self.zodiacSign = zodiacSign
        self.mbti = mbti
        self.interests = interests
        self.books = books
        self.sports = sports
        self.profileTags = profileTags
        self.lastSignal = lastSignal
        self.initials = initials
        self.school = school
        self.major = major
        self.company = company
        self.roleTitle = roleTitle
        self.researchExperience = researchExperience
        self.internshipExperience = internshipExperience
        self.familyNotes = familyNotes
        self.partnerName = partnerName
        self.manualClosenessLevel = min(max(manualClosenessLevel, 1), 6)
        self.closenessSignals = closenessSignals
        self.categoryNotes = categoryNotes
    }

    public func belongs(to group: GroupFilter) -> Bool {
        groupLabels.contains(group)
    }

    public var groupLabelsDisplay: String {
        groupLabels.map(\.rawValue).joined(separator: " · ")
    }

    public func groupLabelsTitle(for language: LanguagePreference) -> String {
        groupLabels.map { $0.title(for: language) }.joined(separator: " · ")
    }

    private static func normalizedGroups(_ groups: [GroupFilter], fallback: GroupFilter) -> [GroupFilter] {
        let ordered = groups.reduce(into: [GroupFilter]()) { result, group in
            guard !result.contains(group) else { return }
            result.append(group)
        }
        return ordered.isEmpty ? [fallback] : ordered
    }

    public var closenessSignalsList: [String] {
        closenessSignals
            .split(whereSeparator: { $0 == "\n" || $0 == "|" || $0 == "；" || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public func manualClosenessTitle(for language: LanguagePreference) -> String {
        let zhTitles = [
            1: "普通认识",
            2: "熟人",
            3: "普通朋友",
            4: "好朋友",
            5: "非常亲近",
            6: "核心关系"
        ]
        let enTitles = [
            1: "Acquaintance",
            2: "Familiar",
            3: "Friend",
            4: "Good Friend",
            5: "Very Close",
            6: "Core Relationship"
        ]
        return resolvedLanguage(language) == .zhCN
            ? (zhTitles[manualClosenessLevel] ?? "普通朋友")
            : (enTitles[manualClosenessLevel] ?? "Friend")
    }

    public func categoryNote(_ category: PersonProfileCategory) -> String {
        categoryNotes[category] ?? ""
    }
}

public struct PendingUpdate: Identifiable, Equatable, Sendable {
    public let id: String
    public let sourceEntryID: String?
    public let proposalType: PendingProposalType
    public let payloadJSON: String
    public let confidence: Double
    public let status: PendingUpdateStatus
    public let createdAt: String
    public let decidedAt: String?
    public let errorMessage: String?

    public init(
        id: String,
        sourceEntryID: String?,
        proposalType: PendingProposalType,
        payloadJSON: String,
        confidence: Double,
        status: PendingUpdateStatus,
        createdAt: String,
        decidedAt: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.sourceEntryID = sourceEntryID
        self.proposalType = proposalType
        self.payloadJSON = payloadJSON
        self.confidence = confidence
        self.status = status
        self.createdAt = createdAt
        self.decidedAt = decidedAt
        self.errorMessage = errorMessage
    }

    public var proposal: MemoryAtomProposal? {
        guard proposalType == .memoryAtom else { return nil }
        guard let data = payloadJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MemoryAtomProposal.self, from: data)
    }

    public var profilePatchProposal: PersonProfilePatchProposal? {
        guard proposalType == .personProfilePatch else { return nil }
        guard let data = payloadJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PersonProfilePatchProposal.self, from: data)
    }

    public var type: String {
        if let proposal {
            return proposal.memoryType.displayName
        }
        if let patch = profilePatchProposal {
            return patch.profileCategory.englishTitle
        }
        return proposalType.rawValue
    }

    public var title: String {
        if let proposal {
            return proposal.title
        }
        if let patch = profilePatchProposal {
            return "\(patch.targetDisplayName) - \(patch.profileCategory.englishTitle)"
        }
        return "Untitled proposal"
    }

    public var summary: String {
        if let proposal {
            return proposal.summary
        }
        if let patch = profilePatchProposal {
            return patch.proposedValue
        }
        return payloadJSON
    }

    public var evidence: String {
        proposal?.sourceQuote ?? profilePatchProposal?.sourceQuote ?? "No source quote"
    }

    public var personName: String {
        proposal?.relatedPeople.first?.displayName ?? "Memory"
    }

    public var createdLabel: String {
        parseMemoriaTimestamp(createdAt)?.formatted(date: .abbreviated, time: .shortened) ?? createdAt
    }

    public var sensitivity: MemorySensitivity {
        proposal?.sensitivity ?? profilePatchProposal?.sensitivity ?? .normal
    }

    public var isAIInferred: Bool {
        proposal?.isAIInferred ?? profilePatchProposal?.isAIInferred ?? true
    }

    public var themeNames: [String] {
        proposal?.themes.map(\.name) ?? []
    }

    public var relatedPeople: [RelatedPersonProposal] {
        if let proposal {
            return proposal.relatedPeople
        }
        if let patch = profilePatchProposal {
            return [
                RelatedPersonProposal(
                    displayName: patch.targetDisplayName,
                    matchedPersonID: patch.targetPersonID,
                    matchConfidence: patch.targetPersonID == nil ? 0.6 : 0.95,
                    relationType: "about"
                )
            ]
        }
        return []
    }

    public var reviewCategory: ReviewCategory {
        profilePatchProposal == nil ? ReviewCategory.inferred(from: proposal) : .friendDossier
    }
}

public extension MemoryAtomProposal {
    var hasScheduleSignals: Bool {
        let joined = [
            title,
            summary,
            content,
            sourceQuote
        ]
        .joined(separator: " ")
        .lowercased()

        let scheduleKeywords = [
            "remind",
            "reminder",
            "calendar",
            "schedule",
            "deadline",
            "due",
            "meeting",
            "exam",
            "birthday",
            "interview",
            "提醒",
            "日程",
            "安排",
            "截止",
            "约",
            "见面",
            "考试",
            "生日",
            "面试",
            "准备",
            "明天",
            "今天",
            "下周",
            "本周",
            "下个月"
        ]

        if scheduleKeywords.contains(where: joined.contains) {
            return true
        }

        return joined.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil ||
            joined.range(of: #"\b\d{1,2}/\d{1,2}\b"#, options: .regularExpression) != nil ||
            joined.range(of: #"\d{1,2}\s*(月|/)\s*\d{1,2}\s*(日|号)?"#, options: .regularExpression) != nil
    }
}

public struct ReminderItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let personName: String
    public let dueLabel: String
    public let dueDate: String?
    public let timeLabel: String
    public let context: String
    public let location: String

    public init(
        id: String,
        title: String,
        personName: String,
        dueLabel: String,
        dueDate: String? = nil,
        timeLabel: String = "",
        context: String = "",
        location: String = ""
    ) {
        self.id = id
        self.title = title
        self.personName = personName
        self.dueLabel = dueLabel
        self.dueDate = dueDate
        self.timeLabel = timeLabel
        self.context = context
        self.location = location
    }

    public var isToday: Bool {
        if let dueDateValue {
            return Calendar.current.isDateInToday(dueDateValue)
        }
        let normalized = dueLabel.lowercased()
        return normalized.contains("today") || normalized.contains("今天")
    }

    public var dueDateValue: Date? {
        guard let dueDate else { return nil }
        return parseMemoriaDateOnly(dueDate)
    }

    public var hasConcreteDueDate: Bool {
        dueDateValue != nil
    }
}

public struct GiftIdea: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let personName: String
    public let priceBand: String
    public let rationale: String
    public let risk: String
    public let confirmationQuestion: String
    public let matchScore: Int
    public let surpriseScore: Int
    public let riskLevel: String
    public let practicality: String
    public let emotionalValue: String
    public let needsMoreInfo: Bool

    public init(
        id: String,
        title: String,
        personName: String,
        priceBand: String,
        rationale: String,
        risk: String = "",
        confirmationQuestion: String = "",
        matchScore: Int = 70,
        surpriseScore: Int = 60,
        riskLevel: String = "中",
        practicality: String = "中",
        emotionalValue: String = "中",
        needsMoreInfo: Bool = true
    ) {
        self.id = id
        self.title = title
        self.personName = personName
        self.priceBand = priceBand
        self.rationale = rationale
        self.risk = risk
        self.confirmationQuestion = confirmationQuestion
        self.matchScore = min(max(matchScore, 0), 100)
        self.surpriseScore = min(max(surpriseScore, 0), 100)
        self.riskLevel = riskLevel
        self.practicality = practicality
        self.emotionalValue = emotionalValue
        self.needsMoreInfo = needsMoreInfo
    }
}

public struct ReminderNotificationPlan: Identifiable, Equatable, Sendable {
    public let id: String
    public let reminderID: String
    public let title: String
    public let body: String
    public let dueLabel: String
    public let timeLabel: String

    public var identifier: String { id }

    public init(reminder: ReminderItem) {
        id = "memoria.reminder.\(reminder.id)"
        reminderID = reminder.id
        title = reminder.personName.isEmpty ? reminder.title : "\(reminder.personName)：\(reminder.title)"
        body = [reminder.context, reminder.location].filter { !$0.isEmpty }.joined(separator: " · ")
        dueLabel = reminder.dueLabel
        timeLabel = reminder.timeLabel
    }
}

public struct ReminderNotificationPlanner: Sendable {
    public init() {}

    public func plans(for reminders: [ReminderItem]) -> [ReminderNotificationPlan] {
        reminders
            .filter(\.isToday)
            .map(ReminderNotificationPlan.init(reminder:))
    }
}

public enum PeoplePresentationMode: Sendable {
    case directoryAndProfile
    case focusedProfile
}

public struct PeoplePresentationPolicy: Sendable {
    public init() {}

    public static func mode(forAvailableWidth width: Double) -> PeoplePresentationMode {
        width < 1_120 ? .focusedProfile : .directoryAndProfile
    }
}

public enum AgendaAssistantItemKind: String, Sendable {
    case calendarBlock = "calendar_block"
    case preparation
    case followUp = "follow_up"
    case review

    public func title(for language: LanguagePreference) -> String {
        guard resolvedLanguage(language) == .zhCN else {
            switch self {
            case .calendarBlock: return "Calendar"
            case .preparation: return "Prep"
            case .followUp: return "Follow-up"
            case .review: return "Review"
            }
        }

        switch self {
        case .calendarBlock:
            return "日历安排"
        case .preparation:
            return "行前准备"
        case .followUp:
            return "跟进问候"
        case .review:
            return "待确认"
        }
    }
}

public struct AgendaAssistantItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: AgendaAssistantItemKind
    public let title: String
    public let detail: String
    public let timeLabel: String
    public let requiresApproval: Bool

    public init(
        id: String,
        kind: AgendaAssistantItemKind,
        title: String,
        detail: String,
        timeLabel: String,
        requiresApproval: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.timeLabel = timeLabel
        self.requiresApproval = requiresApproval
    }
}

public struct AgendaAssistantPlan: Equatable, Sendable {
    public let summary: String
    public let items: [AgendaAssistantItem]
    public let generatedAt: String

    public init(summary: String, items: [AgendaAssistantItem], generatedAt: String = memoriaTimestamp()) {
        self.summary = summary
        self.items = items
        self.generatedAt = generatedAt
    }

    public static let empty = AgendaAssistantPlan(summary: "", items: [], generatedAt: "")
}

public struct AgendaAssistantWorkflow: Sendable {
    public init() {}

    public func plan(
        prompt: String,
        reminders: [ReminderItem],
        pendingUpdates: [PendingUpdate],
        gifts: [GiftIdea],
        language: LanguagePreference
    ) -> AgendaAssistantPlan {
        let isChinese = resolvedLanguage(language) == .zhCN
        var items: [AgendaAssistantItem] = reminders
            .filter(\.isToday)
            .map { reminder in
                AgendaAssistantItem(
                    id: "agenda-\(reminder.id)",
                    kind: .calendarBlock,
                    title: reminder.title,
                    detail: [reminder.personName, reminder.context, reminder.location].filter { !$0.isEmpty }.joined(separator: " · "),
                    timeLabel: reminder.timeLabel.isEmpty ? reminder.dueLabel : reminder.timeLabel
                )
            }

        if let gift = gifts.first {
            items.append(
                AgendaAssistantItem(
                    id: "agenda-gift-\(gift.id)",
                    kind: .preparation,
                    title: isChinese ? "提前准备礼物或心意" : "Prepare gift or gesture",
                    detail: "\(gift.personName)：\(gift.title)。\(gift.rationale)",
                    timeLabel: isChinese ? "约见前" : "Before meeting"
                )
            )
        }

        if let update = pendingUpdates.first {
            items.append(
                AgendaAssistantItem(
                    id: "agenda-review-\(update.id)",
                    kind: .review,
                    title: isChinese ? "先确认 AI 整理建议" : "Review AI suggestion first",
                    detail: update.summary,
                    timeLabel: isChinese ? "今天" : "Today"
                )
            )
        }

        if items.isEmpty {
            items.append(
                AgendaAssistantItem(
                    id: "agenda-capture",
                    kind: .followUp,
                    title: isChinese ? "记录一个今天要关心的人" : "Capture one person to care about",
                    detail: prompt.isEmpty ? (isChinese ? "AI 只做助手，先从一条明确提醒开始。" : "AI is only an assistant; start from one explicit reminder.") : prompt,
                    timeLabel: isChinese ? "今天" : "Today"
                )
            )
        }

        let summary = isChinese
            ? "已生成 \(items.count) 条行程建议。AI 只做助手，不会直接修改日历；需要你确认后再同步提醒。"
            : "Generated \(items.count) agenda suggestions. AI is an assistant and will not change calendars without approval."
        return AgendaAssistantPlan(summary: summary, items: items)
    }
}

public struct MemoryOrganizationSuggestion: Identifiable, Equatable, Sendable {
    public let id: String
    public let targetType: MemoryAtomType
    public let title: String
    public let rationale: String
    public let memoryCount: Int
    public let requiresApproval: Bool

    public init(
        targetType: MemoryAtomType,
        title: String,
        rationale: String,
        memoryCount: Int,
        requiresApproval: Bool = false
    ) {
        self.id = "organize-\(targetType.rawValue)"
        self.targetType = targetType
        self.title = title
        self.rationale = rationale
        self.memoryCount = memoryCount
        self.requiresApproval = requiresApproval
    }
}

public struct MemoryAutoOrganizer: Sendable {
    public init() {}

    public func suggestions(
        for memories: [MemoryAtom],
        language: LanguagePreference
    ) -> [MemoryOrganizationSuggestion] {
        let grouped = Dictionary(grouping: memories, by: \.type)
        let isChinese = resolvedLanguage(language) == .zhCN

        return grouped.keys.sorted { $0.rawValue < $1.rawValue }.map { type in
            let count = grouped[type]?.count ?? 0
            return MemoryOrganizationSuggestion(
                targetType: type,
                title: isChinese ? "已自动整理到「\(type.displayName(for: language))」" : "Auto-organized into \(type.displayName(for: language))",
                rationale: isChinese
                    ? "发现 \(count) 条已确认记忆属于这个分类。分类会随已确认记忆自动更新，你仍可以编辑记忆内容、标签和关系。"
                    : "Found \(count) confirmed memories for this category. Organization updates automatically from confirmed memories, and you can still edit memory content, tags, and relationships.",
                memoryCount: count
            )
        }
    }
}

public struct ImportedFile: Identifiable, Equatable, Sendable {
    public let id: String
    public let filename: String
    public let status: String
    public let progress: Double
}

public struct RelationshipEdge: Identifiable, Equatable, Sendable {
    public let id: String
    public let sourceID: String
    public let sourceName: String
    public let targetID: String
    public let targetName: String
    public let label: String
    public let strength: Double
    public let relationKind: String
    public let sourceMemoryID: String?
    public let confidence: Double
    public let isAIInferred: Bool
    public let tags: [String]
    public let aiPrimaryTag: String?
    public let manualPrimaryTag: String?

    public init(
        id: String,
        sourceID: String = "",
        sourceName: String,
        targetID: String = "",
        targetName: String,
        label: String,
        strength: Double,
        relationKind: String = "friend",
        sourceMemoryID: String? = nil,
        confidence: Double = 0,
        isAIInferred: Bool = false,
        tags: [String] = [],
        aiPrimaryTag: String? = nil,
        manualPrimaryTag: String? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.targetID = targetID
        self.targetName = targetName
        self.label = label
        self.strength = min(max(strength, 0), 1)
        self.relationKind = relationKind
        self.sourceMemoryID = sourceMemoryID
        self.confidence = min(max(confidence, 0), 1)
        self.isAIInferred = isAIInferred
        self.tags = Self.normalizedTags(tags)
        self.aiPrimaryTag = Self.trimmedOptional(aiPrimaryTag)
        self.manualPrimaryTag = Self.trimmedOptional(manualPrimaryTag)
    }

    public func involves(personID: String) -> Bool {
        sourceID == personID || targetID == personID
    }

    public func counterpartName(for personID: String) -> String {
        sourceID == personID ? targetName : sourceName
    }

    public func displayTag(priorities: [RelationshipTagPriority]) -> String {
        if let manualPrimaryTag {
            return manualPrimaryTag
        }

        let priorityRank = Dictionary(uniqueKeysWithValues: priorities.map { ($0.tag, $0.rank) })
        if let tag = tags.min(by: { lhs, rhs in
            let lhsRank = priorityRank[lhs] ?? Int.max
            let rhsRank = priorityRank[rhs] ?? Int.max
            return lhsRank == rhsRank ? lhs < rhs : lhsRank < rhsRank
        }) {
            return tag
        }

        if let aiPrimaryTag {
            return aiPrimaryTag
        }

        return label
    }

    private static func normalizedTags(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { result, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !result.contains(trimmed) else { return }
            result.append(trimmed)
        }
    }

    private static func trimmedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct RelationshipMapLayoutMetrics: Equatable, Sendable {
    public let scale: Double
    public let centerNodeSize: Double
    public let firstHopNodeSize: Double
    public let secondHopNodeSize: Double
    public let firstHopRadius: Double
    public let secondHopRadius: Double
    public let labelMaxWidth: Double
    public let edgeLabelOffset: Double
    public let showsSecondaryEdgeLabels: Bool

    public init(
        scale: Double,
        centerNodeSize: Double,
        firstHopNodeSize: Double,
        secondHopNodeSize: Double,
        firstHopRadius: Double,
        secondHopRadius: Double,
        labelMaxWidth: Double,
        edgeLabelOffset: Double,
        showsSecondaryEdgeLabels: Bool
    ) {
        self.scale = scale
        self.centerNodeSize = centerNodeSize
        self.firstHopNodeSize = firstHopNodeSize
        self.secondHopNodeSize = secondHopNodeSize
        self.firstHopRadius = firstHopRadius
        self.secondHopRadius = secondHopRadius
        self.labelMaxWidth = labelMaxWidth
        self.edgeLabelOffset = edgeLabelOffset
        self.showsSecondaryEdgeLabels = showsSecondaryEdgeLabels
    }
}

public enum RelationshipMapLayoutPolicy {
    public static func metrics(width: Double, height: Double) -> RelationshipMapLayoutMetrics {
        let safeWidth = max(width, 1)
        let safeHeight = max(height, 1)
        let shortSide = min(safeWidth, safeHeight)
        let scale = min(max(shortSide / 620, 0.58), 1.0)
        let nodeEnvelope = 88 * scale
        let horizontalMargin = max(28, 42 * scale)
        let verticalMargin = max(34, 52 * scale)
        let maxRadiusX = max(56, safeWidth / 2 - horizontalMargin - nodeEnvelope / 2)
        let maxRadiusY = max(56, safeHeight / 2 - verticalMargin - nodeEnvelope / 2)
        let outerLimit = min(maxRadiusX, maxRadiusY)
        let secondHopRadius = max(56, min(outerLimit, outerLimit * 0.92))
        let firstHopRadius = max(44, min(secondHopRadius * 0.58, secondHopRadius - 30 * scale))

        return RelationshipMapLayoutMetrics(
            scale: scale,
            centerNodeSize: max(42, 58 * scale),
            firstHopNodeSize: max(36, 48 * scale),
            secondHopNodeSize: max(32, 40 * scale),
            firstHopRadius: firstHopRadius,
            secondHopRadius: secondHopRadius,
            labelMaxWidth: max(64, 112 * scale),
            edgeLabelOffset: max(8, 16 * scale),
            showsSecondaryEdgeLabels: shortSide >= 620 && scale >= 0.95
        )
    }
}

public struct FocusItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let detail: String
    public let target: SidebarSelection
    public let priority: FocusPriority
}

public struct CountItem: Identifiable, Equatable, Sendable {
    public let label: String
    public let count: Int

    public var id: String { label }
}

public struct SearchResult: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let excerpt: String
    public let source: String
}

public func memoriaTimestamp(from date: Date = Date()) -> String {
    makeMemoriaDateFormatter().string(from: date)
}

public func parseMemoriaTimestamp(_ value: String) -> Date? {
    makeMemoriaDateFormatter().date(from: value)
}

public func memoriaDateOnlyString(from date: Date = Date()) -> String {
    makeMemoriaDateOnlyFormatter().string(from: date)
}

public func memoriaDateOnlyString(daysFromNow days: Int, calendar: Calendar = .current) -> String {
    let date = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
    return memoriaDateOnlyString(from: date)
}

public func parseMemoriaDateOnly(_ value: String) -> Date? {
    makeMemoriaDateOnlyFormatter().date(from: value)
}

private func makeMemoriaDateFormatter() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}

private func makeMemoriaDateOnlyFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}
