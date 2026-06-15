import Foundation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case focus
    case inbox
    case people
    case calendar
    case relationshipMap
    case search
    case files
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            "Today"
        case .inbox:
            "AI Inbox"
        case .people:
            "People"
        case .calendar:
            "Calendar"
        case .relationshipMap:
            "Relationship Map"
        case .search:
            "Search"
        case .files:
            "Files"
        case .settings:
            "Settings"
        }
    }

    func title(for language: LanguagePreference) -> String {
        guard resolvedLanguage(language) == .zhCN else {
            return title
        }

        switch self {
        case .focus:
            return "今日"
        case .inbox:
            return "待确认"
        case .people:
            return "联系人"
        case .calendar:
            return "日历"
        case .relationshipMap:
            return "关系星图"
        case .search:
            return "搜索"
        case .files:
            return "文件"
        case .settings:
            return "设置"
        }
    }

    var symbolName: String {
        switch self {
        case .focus:
            "sparkles"
        case .inbox:
            "tray"
        case .people:
            "person.2"
        case .calendar:
            "calendar"
        case .relationshipMap:
            "point.3.connected.trianglepath.dotted"
        case .search:
            "magnifyingglass"
        case .files:
            "doc.badge.arrow.up"
        case .settings:
            "gearshape"
        }
    }
}

enum GroupFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case classmates = "Classmates"
    case studyAbroad = "Study Abroad"
    case homeFriends = "Home Friends"
    case internship = "Internship"

    var id: String { rawValue }

    func title(for language: LanguagePreference) -> String {
        guard resolvedLanguage(language) == .zhCN else {
            return rawValue
        }

        switch self {
        case .all:
            return "全部"
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

enum FocusPriority: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var tint: Color {
        switch self {
        case .high:
            .memoriaGold
        case .medium:
            .memoriaSage
        case .low:
            .secondary
        }
    }
}

struct FriendPerson: Identifiable, Equatable {
    let id: String
    let displayName: String
    let relationLabel: String
    let groupLabel: GroupFilter
    let location: String
    let birthday: String
    let dietaryRestrictions: String
    let favoriteFoods: String
    let dislikedThings: String
    let zodiacSign: String
    let mbti: String
    let interests: String
    let books: String
    let sports: String
    let profileTags: String
    let lastSignal: String
    let initials: String
}

struct PendingUpdate: Identifiable, Equatable {
    let id: String
    let type: String
    let summary: String
    let evidence: String
    let personName: String
    let createdLabel: String
}

struct ReminderItem: Identifiable, Equatable {
    let id: String
    let title: String
    let personName: String
    let dueLabel: String
}

struct GiftIdea: Identifiable, Equatable {
    let id: String
    let title: String
    let personName: String
    let priceBand: String
    let rationale: String
}

struct ImportedFile: Identifiable, Equatable {
    let id: String
    let filename: String
    let status: String
    let progress: Double
}

struct FocusItem: Identifiable, Equatable {
    let id: String
    let label: String
    let detail: String
    let targetTab: AppTab
    let priority: FocusPriority
}

struct SearchResult: Identifiable, Equatable {
    let id: String
    let title: String
    let excerpt: String
    let source: String
}

struct DashboardSnapshot: Equatable {
    var people: [FriendPerson]
    var pendingUpdates: [PendingUpdate]
    var reminders: [ReminderItem]
    var gifts: [GiftIdea]
    var files: [ImportedFile]

    var activePeopleCount: Int { people.count }
    var pendingReviewCount: Int { pendingUpdates.count }
    var upcomingReminderCount: Int { reminders.count }
    var giftOpportunityCount: Int { gifts.count }

    var focusItems: [FocusItem] {
        var items: [FocusItem] = []

        if let firstUpdate = pendingUpdates.first {
            items.append(
                FocusItem(
                    id: "review-\(firstUpdate.id)",
                    label: "Review \(firstUpdate.personName)",
                    detail: firstUpdate.summary,
                    targetTab: .inbox,
                    priority: .high
                )
            )
        }

        if let firstReminder = reminders.first {
            items.append(
                FocusItem(
                    id: "reminder-\(firstReminder.id)",
                    label: "Reach out to \(firstReminder.personName)",
                    detail: "\(firstReminder.title) - \(firstReminder.dueLabel)",
                    targetTab: .people,
                    priority: .high
                )
            )
        }

        if let firstGift = gifts.first {
            items.append(
                FocusItem(
                    id: "gift-\(firstGift.id)",
                    label: "Gift idea for \(firstGift.personName)",
                    detail: "\(firstGift.title) - \(firstGift.priceBand)",
                    targetTab: .search,
                    priority: .medium
                )
            )
        }

        return items
    }

    var askSuggestions: [String] {
        [
            pendingUpdates.first.map { "What should I review for \($0.personName)?" } ?? "What should I review today?",
            "Who needs attention this week?",
            gifts.first.map { "What gift fits \($0.personName)?" } ?? "What gift ideas do I have?"
        ]
    }

    func nextAction(for person: FriendPerson) -> String {
        if pendingUpdates.contains(where: { $0.personName == person.displayName }) {
            return "Review pending update"
        }

        if reminders.contains(where: { $0.personName == person.displayName }) {
            return "Prepare for reminder"
        }

        if gifts.contains(where: { $0.personName == person.displayName }) {
            return "Check gift idea"
        }

        return "Capture one fresh signal"
    }

    func groupCount(_ group: GroupFilter) -> Int {
        if group == .all {
            return people.count
        }

        return people.filter { $0.groupLabel == group }.count
    }

    func search(_ query: String) -> [SearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedQuery.isEmpty {
            return []
        }

        var results: [SearchResult] = []

        for update in pendingUpdates where update.summary.lowercased().contains(normalizedQuery) || update.personName.lowercased().contains(normalizedQuery) {
            results.append(
                SearchResult(
                    id: "update-\(update.id)",
                    title: update.personName,
                    excerpt: update.summary,
                    source: "AI Inbox - \(update.createdLabel)"
                )
            )
        }

        for person in people where person.displayName.lowercased().contains(normalizedQuery) || person.lastSignal.lowercased().contains(normalizedQuery) {
            results.append(
                SearchResult(
                    id: "person-\(person.id)",
                    title: person.displayName,
                    excerpt: person.lastSignal,
                    source: "\(person.groupLabel.rawValue) - \(person.location)"
                )
            )
        }

        for gift in gifts where gift.personName.lowercased().contains(normalizedQuery) || gift.rationale.lowercased().contains(normalizedQuery) {
            results.append(
                SearchResult(
                    id: "gift-\(gift.id)",
                    title: gift.title,
                    excerpt: gift.rationale,
                    source: "Gift Ideas - \(gift.personName)"
                )
            )
        }

        return results
    }
}
