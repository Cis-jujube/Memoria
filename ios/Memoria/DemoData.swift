import Foundation

extension DashboardSnapshot {
    static let demo = DashboardSnapshot(
        people: [
            FriendPerson(
                id: "demo-alex",
                displayName: "Alex Chen",
                relationLabel: "Roommate - Classmate",
                groupLabel: .classmates,
                location: "Beijing / NYU",
                birthday: "Nov 3",
                dietaryRestrictions: "不吃香菜",
                favoriteFoods: "火锅、毛肚、虾滑",
                dislikedThings: "临时改计划、太吵的自习室",
                zodiacSign: "Scorpio",
                mbti: "INTJ",
                interests: "数学、篮球、效率工具",
                books: "Atomic Habits, 置身事内",
                sports: "篮球、健身",
                profileTags: "室友, 考试, 火锅",
                lastSignal: "Calculus midterm on May 20",
                initials: "AC"
            ),
            FriendPerson(
                id: "demo-may",
                displayName: "May Zhang",
                relationLabel: "Close friend - Literature club",
                groupLabel: .homeFriends,
                location: "Shanghai",
                birthday: "May 16",
                dietaryRestrictions: "少冰，不太能吃辣",
                favoriteFoods: "抹茶、日料、桂花乌龙",
                dislikedThings: "敷衍的群发祝福",
                zodiacSign: "Taurus",
                mbti: "INFP",
                interests: "音乐、拍立得、文学社、香水",
                books: "夜航西飞, The Midnight Library",
                sports: "瑜伽、散步",
                profileTags: "生日, 礼物, 文学社",
                lastSignal: "Likes music, instant photos, and ritual gifts",
                initials: "MZ"
            ),
            FriendPerson(
                id: "demo-jason",
                displayName: "Jason Wu",
                relationLabel: "Senior - Internship referral",
                groupLabel: .internship,
                location: "NYC",
                birthday: "Aug 9",
                dietaryRestrictions: "工作日少糖",
                favoriteFoods: "冷萃、牛排、越南粉",
                dislikedThings: "没有 agenda 的长会",
                zodiacSign: "Leo",
                mbti: "ENTJ",
                interests: "创业、跑步、职业规划",
                books: "The Hard Thing About Hard Things",
                sports: "跑步、攀岩",
                profileTags: "学长, 内推, 职业",
                lastSignal: "Starts full-time work in June",
                initials: "JW"
            )
        ],
        pendingUpdates: [
            PendingUpdate(
                id: "p1",
                type: "Preference",
                summary: "Alex does not eat cilantro and likes hotpot tripe and shrimp paste.",
                evidence: "Dinner note from yesterday with Alex",
                personName: "Alex Chen",
                createdLabel: "Today, 8:45 PM"
            ),
            PendingUpdate(
                id: "p2",
                type: "Event",
                summary: "Alex has a calculus midterm on May 20 and wants a high score.",
                evidence: "Preparing for the May 20 calculus midterm",
                personName: "Alex Chen",
                createdLabel: "Today, 8:40 PM"
            ),
            PendingUpdate(
                id: "p3",
                type: "Birthday",
                summary: "May's birthday is May 16; she likes music and instant photos.",
                evidence: "Birthday note captured from chat",
                personName: "May Zhang",
                createdLabel: "Today, 7:12 PM"
            )
        ],
        reminders: [
            ReminderItem(
                id: "r1",
                title: "May Zhang birthday",
                personName: "May Zhang",
                dueLabel: "May 16 - in 2 days"
            ),
            ReminderItem(
                id: "r2",
                title: "Alex calculus midterm",
                personName: "Alex Chen",
                dueLabel: "May 20 - in 6 days"
            ),
            ReminderItem(
                id: "r3",
                title: "Group study",
                personName: "Classmates",
                dueLabel: "May 18 - 7:00 PM"
            )
        ],
        gifts: [
            GiftIdea(
                id: "g1",
                title: "BYREDO fragrance set",
                personName: "May Zhang",
                priceBand: "$$",
                rationale: "May likes music, instant photos, and gifts with a ritual feeling."
            ),
            GiftIdea(
                id: "g2",
                title: "AirPods Pro 2",
                personName: "Alex Chen",
                priceBand: "$$$",
                rationale: "Alex studies and commutes often, but the budget should be confirmed."
            )
        ],
        files: [
            ImportedFile(
                id: "f1",
                filename: "IMG_20250512_1213.jpg",
                status: "OCR processing",
                progress: 0.82
            ),
            ImportedFile(
                id: "f2",
                filename: "Lecture_Notes_ML.pdf",
                status: "23 notes extracted",
                progress: 1
            )
        ]
    )
}
