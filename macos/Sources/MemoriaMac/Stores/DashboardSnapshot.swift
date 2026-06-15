import Foundation

public struct DashboardSnapshot: Sendable {
    public let people: [FriendPerson]
    public let pendingUpdates: [PendingUpdate]
    public let memoryAtoms: [MemoryAtom]
    public let themes: [Theme]
    public let reminders: [ReminderItem]
    public let gifts: [GiftIdea]
    public let files: [ImportedFile]
    public let relationshipEdges: [RelationshipEdge]
    public let relationshipTagPriorities: [RelationshipTagPriority]
}

extension DashboardSnapshot {
    public static let demo = DashboardSnapshot(
        people: [
            FriendPerson(
                id: "demo-alex",
                displayName: "Alex Chen",
                nickname: "Alex",
                englishName: "Alex Chen",
                relationLabel: "Roommate - Classmate",
                groupLabel: .classmates,
                groupLabels: [.classmates, .internship],
                location: "Beijing / NYU",
                hometown: "北京",
                languages: "中文、English",
                contactInfo: "微信优先，紧急事情再打电话",
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
                initials: "AC",
                school: "NYU",
                major: "Mathematics",
                company: "Campus Research Lab",
                roleTitle: "Research Assistant",
                researchExperience: "参与图优化和学习行为分析项目，最近在整理期中复习数据。",
                internshipExperience: "计划申请数据科学暑研，正在准备 Jason 推荐的简历版本。",
                familyNotes: "姐姐在北京工作，家里通常十一月一起庆生。",
                partnerName: "暂未记录",
                manualClosenessLevel: 4,
                closenessSignals: "最近互动频率：同住且经常一起复习；共同重大经历：一起准备期中；是否会互相求助：会问作业和简历；固定习惯：周末可能一起吃火锅；最近需要关心：5 月 20 日微积分期中",
                categoryNotes: makeProfileNotes([
                    .identity: "姓名 Alex Chen；昵称 Alex；生日 11 月 3 日；星座 Scorpio；MBTI INTJ；城市 Beijing / NYU。",
                    .contact: "微信优先；学习相关问题适合文字，不喜欢无 agenda 长电话。",
                    .relationship: "室友兼同学；一起准备期中；边界是不临时改计划、不把学习压力公开调侃。",
                    .education: "NYU Mathematics；近期课程重点是 Calculus 和 ML。",
                    .career: "关注数据科学暑研；正在准备简历和推荐材料。",
                    .family: "姐姐在北京工作；家里重视生日。",
                    .friendNetwork: "Jason 给过职业建议；和 May 有课程项目弱连接。",
                    .interests: "数学、篮球、效率工具、健身。",
                    .media: "Atomic Habits；置身事内。",
                    .foodPreference: "火锅、毛肚、虾滑；喜欢安静一点的餐厅。",
                    .dietaryAllergy: "不吃香菜。",
                    .lifestyle: "偏规律，考试前会晚睡；喜欢高效率安排。",
                    .currentState: "正在准备 5 月 20 日微积分期中。",
                    .lifeEvents: "近期考试；后续可能申请暑研。",
                    .emotionalPreference: "适合低压力提醒，不适合公开催促。",
                    .communicationPreference: "学习问题适合文字；需要明确问题和 agenda。",
                    .tabooBoundary: "不要临时改计划；不要把成绩压力拿来开玩笑。",
                    .reminders: "期中前问候；考后约火锅。",
                    .files: "可关联简历版本、课程笔记、聊天截图。",
                    .aiInference: "推断：如果复习压力高，实用型帮助比情绪化安慰更合适。"
                ])
            ),
            FriendPerson(
                id: "demo-may",
                displayName: "May Zhang",
                nickname: "小雨",
                englishName: "May Zhang",
                relationLabel: "Close friend - Literature club",
                groupLabel: .homeFriends,
                location: "Shanghai",
                hometown: "上海",
                languages: "中文、English",
                contactInfo: "微信文字优先；重要事情可以约线下慢慢聊",
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
                initials: "MZ",
                school: "复旦大学",
                major: "中文系",
                company: "文学社",
                roleTitle: "活动策划",
                researchExperience: "做过女性书写和城市记忆主题读书会整理。",
                internshipExperience: "曾在出版社做暑期编辑助理。",
                familyNotes: "妈妈喜欢桂花乌龙，生日时会一起吃日料。",
                partnerName: "Leo",
                manualClosenessLevel: 5,
                closenessSignals: "最近互动频率：近两周聊天变多；共同重大经历：文学社活动和生日聚会；是否知道彼此私人信息：知道她换工作压力；是否会互相求助：会请你帮她看文案；固定约饭/聊天习惯：常约日料和咖啡；未回复/疏远迹象：没有明显疏远；最近需要关心的事件：换工作压力和生日安排",
                categoryNotes: makeProfileNotes([
                    .identity: "姓名 May Zhang；昵称小雨；生日 5 月 16 日；星座 Taurus；MBTI INFP；城市上海。",
                    .contact: "微信文字优先；不喜欢敷衍群发祝福。",
                    .relationship: "文学社好朋友；关系阶段稳定亲近；相处边界是不要过度追问私人压力。",
                    .education: "复旦大学中文系；参与女性书写和城市记忆读书会。",
                    .career: "曾在出版社做编辑助理；最近考虑换工作。",
                    .family: "妈妈喜欢桂花乌龙；生日经常一起吃日料。",
                    .friendNetwork: "和 Leo 是伴侣关系；和 Alex 因课程项目有互动。",
                    .interests: "音乐、拍立得、文学社、香水、陶艺、旅行。",
                    .media: "夜航西飞；The Midnight Library；偏爱有情绪质感的音乐。",
                    .foodPreference: "日料、抹茶、桂花乌龙；饮料少冰。",
                    .dietaryAllergy: "不太能吃辣；暂未记录过敏。",
                    .travelPreference: "8 月计划去冰岛；偏自然景观和拍照体验。",
                    .styleAesthetic: "喜欢温柔但不甜腻的颜色；小众香氛；拍立得风格。",
                    .spendingPreference: "更喜欢有心意和仪式感的礼物，不一定追求大牌。",
                    .giftHistory: "适合体验型、旅行实用型或低压力陪伴型；踩雷是太普通、太功能化或像群发。",
                    .lifestyle: "喜欢散步、瑜伽、咖啡馆；压力大时需要空间。",
                    .currentState: "生日临近；换工作阶段压力偏高；也在学陶艺。",
                    .lifeEvents: "生日、换工作、8 月冰岛旅行。",
                    .emotionalPreference: "适合温柔陪伴，不适合直接评价她状态不好。",
                    .communicationPreference: "适合文字和线下深聊；不要突然电话。",
                    .tabooBoundary: "不要把工作压力当玩笑；不要暗示她状态很差。",
                    .anniversaries: "5 月 16 日生日；文学社活动纪念日待补。",
                    .reminders: "生日礼物、冰岛旅行前提醒、换工作阶段低压力问候。",
                    .files: "可关联作品集、旅行清单、聊天截图、照片说明。",
                    .aiInference: "推断：她可能更喜欢带个人理解的体验礼物，而不是标准爆款。"
                ])
            ),
            FriendPerson(
                id: "demo-jason",
                displayName: "Jason Wu",
                nickname: "Jason",
                englishName: "Jason Wu",
                relationLabel: "Senior - Internship referral",
                groupLabel: .internship,
                groupLabels: [.internship, .classmates],
                location: "NYC",
                hometown: "杭州",
                languages: "中文、English",
                contactInfo: "LinkedIn/邮件适合正式事项；微信适合快速确认",
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
                initials: "JW",
                school: "Columbia University",
                major: "Computer Science",
                company: "Northstar Analytics",
                roleTitle: "Data Analyst Intern",
                researchExperience: "做过推荐系统评估和 A/B 实验设计。",
                internshipExperience: "曾在金融科技团队做数据分析实习。",
                familyNotes: "父母在杭州，经常提醒他注意作息。",
                partnerName: "暂未记录",
                manualClosenessLevel: 3,
                closenessSignals: "最近互动频率：职业问题时联系；是否会互相求助：你会向他请教实习；固定习惯：无固定聊天；最近需要关心：6 月入职",
                categoryNotes: makeProfileNotes([
                    .identity: "Jason Wu；Leo；NYC；ENTJ。",
                    .contact: "正式事情邮件或 LinkedIn，快速确认用微信。",
                    .relationship: "学长和实习内推关系；边界是提前准备问题，不空泛占用时间。",
                    .education: "Columbia University Computer Science。",
                    .career: "Northstar Analytics Data Analyst Intern；关注数据分析、A/B 实验和职业规划。",
                    .family: "父母在杭州。",
                    .interests: "创业、跑步、攀岩、职业规划。",
                    .foodPreference: "冷萃、牛排、越南粉；工作日少糖。",
                    .currentState: "6 月开始 full-time work。",
                    .reminders: "入职前祝福；秋招节点请教。",
                    .aiInference: "推断：高效率、目标明确的沟通更适合他。"
                ])
            ),
            FriendPerson(
                id: "demo-nina",
                displayName: "Nina Park",
                nickname: "Nina",
                englishName: "Nina Park",
                relationLabel: "Exchange friend - Seoul",
                groupLabel: .studyAbroad,
                groupLabels: [.studyAbroad, .classmates],
                location: "Seoul",
                hometown: "Seoul",
                languages: "Korean、English、中文一点点",
                contactInfo: "Instagram 和微信都可以，旅行照片适合 IG",
                birthday: "Feb 21",
                dietaryRestrictions: "少喝奶制品",
                favoriteFoods: "紫菜包饭、冷面、草莓蛋糕",
                dislikedThings: "太临时的出行安排",
                zodiacSign: "Aquarius",
                mbti: "ENFP",
                interests: "旅行、韩语、摄影、城市漫步",
                books: "Pachinko, 旅行的艺术",
                sports: "普拉提、徒步",
                profileTags: "水瓶, 交换, 旅行",
                lastSignal: "Planning a study abroad reunion",
                initials: "NP",
                school: "Yonsei University",
                major: "Media Studies",
                company: "Campus Media Lab",
                roleTitle: "Exchange Student",
                researchExperience: "关注城市影像和社交媒体叙事。",
                internshipExperience: "在独立影展做过志愿者和内容整理。",
                familyNotes: "哥哥在首尔，常一起规划周末城市漫步。",
                partnerName: "Min",
                manualClosenessLevel: 4,
                closenessSignals: "最近互动频率：旅行计划时较多；共同重大经历：交换项目；固定习惯：分享城市漫步照片；最近需要关心：交换重聚计划",
                categoryNotes: makeProfileNotes([
                    .identity: "Nina Park；Seoul；Aquarius；ENFP。",
                    .contact: "Instagram 适合照片分享；微信适合约行程。",
                    .relationship: "交换朋友；和 Min 是伴侣关系。",
                    .education: "Yonsei University Media Studies；交换经历明确。",
                    .family: "哥哥在首尔。",
                    .interests: "旅行、韩语、摄影、城市漫步、普拉提、徒步。",
                    .travelPreference: "喜欢城市漫步和摄影点，不喜欢太临时的出行安排。",
                    .styleAesthetic: "偏自然、轻松、适合拍照的风格。",
                    .reminders: "交换重聚计划；旅行前确认路线。",
                    .aiInference: "推断：和旅行/摄影相关的小礼物更容易有情感价值。"
                ])
            )
        ],
        pendingUpdates: [
            makeDemoPendingUpdate(
                id: "p1",
                personID: "demo-alex",
                personName: "Alex",
                title: "Alex 不吃香菜",
                summary: "Alex does not eat cilantro and likes hotpot tripe and shrimp paste.",
                sourceQuote: "Alex 不吃香菜，但是很喜欢火锅里的毛肚和虾滑。",
                type: .personFact,
                themes: ["饮食忌口", "朋友支持"]
            ),
            makeDemoPendingUpdate(
                id: "p2",
                personID: "demo-alex",
                personName: "Alex",
                title: "Alex 的微积分期中考试",
                summary: "Alex has a calculus midterm on May 20 and wants a high score.",
                sourceQuote: "Alex 在准备 5 月 20 日的微积分期中考试。",
                type: .event,
                themes: ["求职压力", "朋友支持"]
            ),
            makeDemoPendingUpdate(
                id: "p3",
                personID: "demo-may",
                personName: "May",
                title: "May 喜欢有仪式感的生日礼物",
                summary: "May's birthday is May 16; she likes music and instant photos.",
                sourceQuote: "May 生日快到了，她喜欢音乐、拍立得和有仪式感的小礼物。",
                type: .giftSignal,
                themes: ["生日礼物"]
            )
        ],
        memoryAtoms: [
            makeDemoMemory(
                id: "mem-demo-reflection",
                type: .personalReflection,
                title: "我在人际关系里害怕麻烦别人",
                summary: "和 Alex 相关的记录反复出现“怕麻烦对方”的感受。",
                content: "这是一条关于自我表达和关系边界的反思，需要继续观察什么时候最容易压下自己的需求。",
                sourceQuote: "我好像总是怕麻烦 Alex，所以很多事情没说。",
                sensitivity: .private
            ),
            makeDemoMemory(
                id: "mem-demo-relationship",
                type: .relationshipMemory,
                title: "May 和 Alex 在课题项目里互动频繁",
                summary: "May 与 Alex 最近因为 class project 交流变多，可以在关系网里作为弱连接查看。",
                content: "这条记忆用于解释 Alex 与 May 的项目关系，而不是自动判断亲密程度。",
                sourceQuote: "May 说 Alex 最近经常问她 class project 的材料。",
                sensitivity: .normal
            ),
            makeDemoMemory(
                id: "mem-demo-gift",
                type: .giftSignal,
                title: "May 喜欢有仪式感的小礼物",
                summary: "May 喜欢音乐、拍立得和香水，更适合有仪式感但不过度亲密的礼物。",
                content: "生日礼物可以考虑拍立得相纸、小型香氛或音乐相关体验。",
                sourceQuote: "May 生日快到了，她喜欢音乐、拍立得和有仪式感的小礼物。",
                sensitivity: .normal
            )
        ],
        themes: defaultSelfIndexThemePresets.map {
            Theme(
                id: "theme-\($0.name)",
                name: $0.name,
                description: $0.description,
                createdAt: memoriaTimestamp(),
                updatedAt: memoriaTimestamp()
            )
        },
        reminders: [
            ReminderItem(
                id: "r1",
                title: "给 May 准备生日祝福",
                personName: "May Zhang",
                dueLabel: "今天",
                dueDate: memoriaDateOnlyString(daysFromNow: 0),
                timeLabel: "18:30",
                context: "约了 May 晚上吃饭，提前确认餐厅和生日小礼物。",
                location: "静安寺附近"
            ),
            ReminderItem(
                id: "r2",
                title: "提醒 Alex 期中复习",
                personName: "Alex Chen",
                dueLabel: "明天",
                dueDate: memoriaDateOnlyString(daysFromNow: 1),
                timeLabel: "20:00",
                context: "问他微积分错题整理得怎么样，不要直接催。",
                location: "线上"
            ),
            ReminderItem(
                id: "r3",
                title: "小组自习",
                personName: "Classmates",
                dueLabel: "本周六",
                dueDate: memoriaDateOnlyString(daysFromNow: 6),
                timeLabel: "19:00",
                context: "带上 ML lecture notes 和上次没有讲完的问题。",
                location: "图书馆二层"
            )
        ],
        gifts: [
            GiftIdea(
                id: "g1",
                title: "推荐方向 1：陶艺相关体验或工具",
                personName: "May Zhang",
                priceBand: "300-500 元",
                rationale: "她最近在学陶艺，体验型礼物比单纯物品更贴合当前兴趣。",
                risk: "如果她已经有固定课程，重复购买可能浪费。",
                confirmationQuestion: "她是手作体验型还是想长期学习？",
                matchScore: 92,
                surpriseScore: 82,
                riskLevel: "中",
                practicality: "中",
                emotionalValue: "高",
                needsMoreInfo: true
            ),
            GiftIdea(
                id: "g2",
                title: "推荐方向 2：冰岛旅行相关实用物品",
                personName: "May Zhang",
                priceBand: "300-500 元",
                rationale: "她 8 月要去冰岛，可以送轻便保暖、旅行收纳、拍照相关物品。",
                risk: "功能性礼物如果审美不合，惊喜感不足。",
                confirmationQuestion: "她已经买了哪些旅行装备？她偏什么颜色？",
                matchScore: 86,
                surpriseScore: 70,
                riskLevel: "中",
                practicality: "高",
                emotionalValue: "中",
                needsMoreInfo: true
            ),
            GiftIdea(
                id: "g3",
                title: "推荐方向 3：换工作阶段的低压力陪伴礼物",
                personName: "May Zhang",
                priceBand: "300-500 元",
                rationale: "她最近压力较大，适合送香薰、按摩、睡眠、轻办公相关物品。",
                risk: "不要显得像在暗示她状态不好。",
                confirmationQuestion: "她最近更需要放松、效率，还是有人陪她聊聊？",
                matchScore: 84,
                surpriseScore: 76,
                riskLevel: "低",
                practicality: "高",
                emotionalValue: "高",
                needsMoreInfo: false
            ),
            GiftIdea(
                id: "g4",
                title: "降噪耳机预算确认",
                personName: "Alex Chen",
                priceBand: "$$$",
                rationale: "Alex 经常学习和通勤，降噪耳机会实用，但预算和已有设备需要确认。",
                risk: "预算偏高，而且他可能已经有类似设备。",
                confirmationQuestion: "他现在用什么耳机？预算是否适合？",
                matchScore: 74,
                surpriseScore: 58,
                riskLevel: "中",
                practicality: "高",
                emotionalValue: "中",
                needsMoreInfo: true
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
            ),
            ImportedFile(
                id: "f3",
                filename: "Wechat_Export_May.json",
                status: "Pending review",
                progress: 0.35
            )
        ],
        relationshipEdges: [
            RelationshipEdge(
                id: "e1",
                sourceID: "demo-alex",
                sourceName: "Alex Chen",
                targetID: "demo-may",
                targetName: "May Zhang",
                label: "课程项目搭档",
                strength: 0.7,
                relationKind: "project",
                tags: ["项目伙伴", "同学"],
                aiPrimaryTag: "项目伙伴"
            ),
            RelationshipEdge(
                id: "e2",
                sourceID: "demo-jason",
                sourceName: "Jason Wu",
                targetID: "demo-alex",
                targetName: "Alex Chen",
                label: "职业建议",
                strength: 0.56,
                relationKind: "mentor",
                tags: ["导师", "职业建议"],
                aiPrimaryTag: "导师"
            ),
            RelationshipEdge(
                id: "e3",
                sourceID: "demo-nina",
                sourceName: "Nina Park",
                targetID: "demo-may",
                targetName: "May Zhang",
                label: "交换朋友",
                strength: 0.62,
                relationKind: "friend",
                tags: ["好朋友", "交换朋友"],
                aiPrimaryTag: "好朋友"
            ),
            RelationshipEdge(
                id: "e4",
                sourceID: "demo-may",
                sourceName: "May Zhang",
                targetID: "external-leo",
                targetName: "Leo",
                label: "男朋友",
                strength: 0.86,
                relationKind: "partner",
                tags: ["恋人", "伴侣"],
                manualPrimaryTag: "恋人"
            )
        ],
        relationshipTagPriorities: defaultRelationshipTagPriorities
    )
}

private func makeProfileNotes(_ notes: [PersonProfileCategory: String]) -> [PersonProfileCategory: String] {
    notes
}

private func makeDemoMemory(
    id: String,
    type: MemoryAtomType,
    title: String,
    summary: String,
    content: String,
    sourceQuote: String,
    sensitivity: MemorySensitivity
) -> MemoryAtom {
    MemoryAtom(
        id: id,
        sourceEntryID: nil,
        type: type,
        title: title,
        summary: summary,
        content: content,
        sourceQuote: sourceQuote,
        confidence: 0.88,
        sensitivity: sensitivity,
        isAIInferred: false,
        status: .confirmed,
        eventTime: nil,
        validUntil: nil,
        createdAt: memoriaTimestamp(),
        updatedAt: memoriaTimestamp()
    )
}

private func makeDemoPendingUpdate(
    id: String,
    personID: String,
    personName: String,
    title: String,
    summary: String,
    sourceQuote: String,
    type: MemoryAtomType,
    themes: [String]
) -> PendingUpdate {
    let proposal = MemoryAtomProposal(
        proposalType: .memoryAtom,
        memoryType: type,
        title: title,
        summary: summary,
        content: summary,
        sourceQuote: sourceQuote,
        confidence: 0.82,
        sensitivity: .normal,
        isAIInferred: false,
        relatedPeople: [
            RelatedPersonProposal(
                displayName: personName,
                matchedPersonID: personID,
                matchConfidence: 0.9,
                relationType: "about"
            )
        ],
        themes: themes.map { ThemeProposal(name: $0, confidence: 0.8) },
        followUpQuestions: [],
        suggestedActions: []
    )
    let payload = (try? JSONEncoder().encode(proposal))
        .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    return PendingUpdate(
        id: id,
        sourceEntryID: nil,
        proposalType: .memoryAtom,
        payloadJSON: payload,
        confidence: proposal.confidence,
        status: .pending,
        createdAt: memoriaTimestamp()
    )
}
