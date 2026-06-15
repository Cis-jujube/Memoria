export type DashboardPerson = {
  id: string;
  displayName: string;
  relationLabel: string;
  groupLabel: string;
  groupIds: string[];
  groupLabels: string[];
  location: string;
  birthday: string;
  birthdayMonth?: number;
  birthdayDay?: number;
  dietaryRestrictions: string;
  favoriteFoods: string;
  dislikedThings: string;
  zodiacSign: string;
  mbti: string;
  interests: string;
  books: string;
  sports: string;
  favoriteThings: string;
  games: string;
  gameTime: string;
  musicAndMedia: string;
  studyNotes: string;
  careerNotes: string;
  lifeNotes: string;
  relationshipNotes: string;
  travel: string;
  communicationStyle: string;
  profileTags: string;
  lastSignal: string;
  initials: string;
  manualClosenessLevel?: number;
  closenessSignals?: string[];
};

export type DashboardReminder = {
  id: string;
  title: string;
  personName: string;
  dueLabel: string;
  dueAt: string;
  type: "reminder" | "birthday" | "life_event";
};

export type DashboardGroup = {
  id: string;
  label: string;
  color: string;
  description: string;
  memberCount: number;
  sortOrder: number;
};

export type DashboardCalendarEvent = {
  id: string;
  title: string;
  personName: string;
  date: string;
  type: "birthday" | "reminder" | "gift" | "ai_suggestion" | "life_event";
  typeLabel: string;
  dayLabel: string;
  density: number;
  sourceId: string;
};

export type DashboardRelationshipScore = {
  personId: string;
  personName: string;
  total: number;
  freshness: number;
  profileDepth: number;
  milestoneCoverage: number;
  interactionWarmth: number;
  boundaryCare: number;
  lifeContext: number;
  studyCareer: number;
  emotionalContext: number;
  tasteMap: number;
  playCulture: number;
  explanation: string;
  recommendation: string;
};

export type DashboardRelationshipGraph = {
  me: {
    id: string;
    name: string;
    initials: string;
  };
  groups: {
    id: string;
    label: string;
    color: string;
    memberCount: number;
    orbit: number;
  }[];
  nodes: {
    id: string;
    label: string;
    initials: string;
    groupId: string;
    groupLabel: string;
    score: number;
    strength: number;
    lastSignal: string;
    hasUpcoming: boolean;
    hasBirthday: boolean;
    orbitIndex: number;
  }[];
  edges: {
    id: string;
    source: string;
    target: string;
    label: string;
    strength: number;
  }[];
};

export type DashboardPendingUpdate = {
  id: string;
  type: string;
  summary: string;
  evidence: string;
  personName: string;
  createdLabel: string;
};

export type DashboardGift = {
  id: string;
  title: string;
  personName: string;
  priceBand: string;
  rationale: string;
};

export type DashboardFile = {
  id: string;
  filename: string;
  status: string;
  progress: number;
};

export type DashboardData = {
  stats: {
    inbox: number;
    reminders: number;
    birthdays: number;
    files: number;
  };
  groups: DashboardGroup[];
  people: DashboardPerson[];
  pendingUpdates: DashboardPendingUpdate[];
  reminders: DashboardReminder[];
  calendarEvents: DashboardCalendarEvent[];
  relationshipScores: DashboardRelationshipScore[];
  relationshipGraph: DashboardRelationshipGraph;
  gifts: DashboardGift[];
  files: DashboardFile[];
};

export const demoDashboardData: DashboardData = {
  stats: {
    inbox: 6,
    reminders: 3,
    birthdays: 2,
    files: 2,
  },
  groups: [
    {
      id: "group-classmates",
      label: "同学",
      color: "#256f56",
      description: "同学、室友和一起上课的人。",
      memberCount: 1,
      sortOrder: 0,
    },
    {
      id: "group-home-friends",
      label: "老朋友",
      color: "#8f5a33",
      description: "老朋友、家乡朋友和长期关系。",
      memberCount: 1,
      sortOrder: 1,
    },
    {
      id: "group-internship",
      label: "实习圈",
      color: "#365d8c",
      description: "实习、职业和学长学姐网络。",
      memberCount: 1,
      sortOrder: 2,
    },
  ],
  people: [
    {
      id: "demo-alex",
      displayName: "Alex Chen",
      relationLabel: "室友 · 同届同学",
      groupLabel: "同学",
      groupIds: ["group-classmates"],
      groupLabels: ["同学"],
      location: "Beijing / NYU",
      birthday: "Nov 3",
      birthdayMonth: 11,
      birthdayDay: 3,
      dietaryRestrictions: "不吃香菜",
      favoriteFoods: "火锅、毛肚、虾滑",
      dislikedThings: "临时改计划、太吵的自习室",
      zodiacSign: "Scorpio",
      mbti: "INTJ",
      interests: "数学、篮球、效率工具",
      books: "Atomic Habits, 置身事内",
      sports: "篮球、健身",
      favoriteThings: "机械键盘、降噪耳机、干净的桌面设置",
      games: "Valorant, Minecraft",
      gameTime: "周末晚上会玩 2-3 小时，考试周会主动停掉",
      musicAndMedia: "偏爱 lo-fi 和科幻电影，喜欢 Nolan 的电影",
      studyNotes: "微积分和数据结构压力最大，喜欢有人一起复盘错题",
      careerNotes: "对量化和后端工程都有兴趣，暑假想找技术实习",
      lifeNotes: "作息偏晚，安静环境下效率最高，讨厌临时改计划",
      relationshipNotes: "不太主动表达情绪，但对具体帮助会记很久",
      travel: "想去东京看电子产品店，也想去川西徒步",
      communicationStyle: "直接、讲逻辑，最好带清楚的时间和 agenda",
      profileTags: "室友, 考试, 火锅",
      lastSignal: "5/20 微积分期中考试",
      initials: "AC",
      manualClosenessLevel: 5,
      closenessSignals: [
        "最近一起吃火锅，有明确饮食偏好记录。",
        "考试节点清楚，适合轻量关心。",
        "同住场景多，但不喜欢临时改计划。",
      ],
    },
    {
      id: "demo-may",
      displayName: "May Zhang",
      relationLabel: "好友 · 文学社",
      groupLabel: "老朋友",
      groupIds: ["group-home-friends"],
      groupLabels: ["老朋友"],
      location: "Shanghai",
      birthday: "May 16",
      birthdayMonth: 5,
      birthdayDay: 16,
      dietaryRestrictions: "少冰，不太能吃辣",
      favoriteFoods: "抹茶、日料、桂花乌龙",
      dislikedThings: "敷衍的群发祝福",
      zodiacSign: "Taurus",
      mbti: "INFP",
      interests: "音乐、拍立得、文学社、香水",
      books: "夜航西飞, The Midnight Library",
      sports: "瑜伽、散步",
      favoriteThings: "拍立得相纸、木质香、手写卡片、现场音乐",
      games: "Stardew Valley, Animal Crossing",
      gameTime: "压力大时会玩一两个晚上，用来放松，不喜欢被催进度",
      musicAndMedia: "独立音乐、爵士现场、宫崎骏电影",
      studyNotes: "文学课阅读量大，喜欢一起讨论文本但不喜欢被打断",
      careerNotes: "考虑出版、品牌内容或文化项目策划",
      lifeNotes: "很重视仪式感和边界感，不喜欢敷衍的群发祝福",
      relationshipNotes: "情绪细腻，别人记得小细节会很加分",
      travel: "想去京都、台南和大理，偏慢节奏路线",
      communicationStyle: "温柔具体，不要太像任务提醒，适合提前约时间",
      profileTags: "生日, 礼物, 文学社",
      lastSignal: "喜欢音乐和拍立得",
      initials: "MZ",
      manualClosenessLevel: 6,
      closenessSignals: [
        "生日和礼物偏好有来源支持。",
        "关系里重视小细节和仪式感。",
        "沟通适合提前约时间，避免模板祝福。",
      ],
    },
    {
      id: "demo-jason",
      displayName: "Jason Wu",
      relationLabel: "学长 · 实习内推",
      groupLabel: "实习圈",
      groupIds: ["group-internship"],
      groupLabels: ["实习圈"],
      location: "NYC",
      birthday: "Aug 9",
      birthdayMonth: 8,
      birthdayDay: 9,
      dietaryRestrictions: "工作日少糖",
      favoriteFoods: "冷萃、牛排、越南粉",
      dislikedThings: "没有 agenda 的长会",
      zodiacSign: "Leo",
      mbti: "ENTJ",
      interests: "创业、跑步、职业规划",
      books: "The Hard Thing About Hard Things",
      sports: "跑步、攀岩",
      favoriteThings: "冷萃、好用的项目管理工具、轻量户外装备",
      games: "Chess.com, Slay the Spire",
      gameTime: "碎片时间下棋，出差路上会玩策略游戏",
      musicAndMedia: "商业播客、创业访谈、纪录片",
      studyNotes: "愿意分享实习面试和简历经验，但不喜欢泛泛而谈",
      careerNotes: "6 月开始全职，关注 AI 产品和早期创业机会",
      lifeNotes: "日程紧，喜欢高效沟通，最好一次说清楚背景和请求",
      relationshipNotes: "可靠但边界感强，感谢要具体，不适合频繁打扰",
      travel: "常去 NYC 和湾区，喜欢顺手探索咖啡店",
      communicationStyle: "先给结论，再补背景；约时间要给备选 slot",
      profileTags: "学长, 内推, 职业",
      lastSignal: "6 月开始全职",
      initials: "JW",
      manualClosenessLevel: 3,
      closenessSignals: [
        "职业线索清晰，但最近互动偏少。",
        "对具体问题回应好，不适合频繁打扰。",
        "下一步适合用明确背景重新联系。",
      ],
    },
  ],
  pendingUpdates: [
    {
      id: "p1",
      type: "偏好",
      summary: "Alex 吃了火锅，他不吃香菜，喜欢毛肚和虾滑。",
      evidence: "昨天和 Alex 吃了火锅...",
      personName: "Alex Chen",
      createdLabel: "Today, 8:45 PM",
    },
    {
      id: "p2",
      type: "事件",
      summary: "Alex 5/20 微积分期中考试，想考高分。",
      evidence: "准备 5/20 的微积分期中考试",
      personName: "Alex Chen",
      createdLabel: "Today, 8:40 PM",
    },
    {
      id: "p3",
      type: "生日",
      summary: "May's birthday is 5/16，喜欢音乐和拍立得。",
      evidence: "May's birthday is 5/16...",
      personName: "May Zhang",
      createdLabel: "Today, 7:12 PM",
    },
  ],
  reminders: [
    {
      id: "r1",
      title: "May Zhang 生日",
      personName: "May Zhang",
      dueLabel: "5 月 16 日 · 2 天后",
      dueAt: "2026-05-16T09:00:00.000Z",
      type: "birthday",
    },
    {
      id: "r2",
      title: "Alex 微积分期中考试",
      personName: "Alex Chen",
      dueLabel: "5 月 20 日 · 6 天后",
      dueAt: "2026-05-20T13:00:00.000Z",
      type: "life_event",
    },
    {
      id: "r3",
      title: "同学小组复习",
      personName: "同学",
      dueLabel: "5 月 18 日 · 19:00",
      dueAt: "2026-05-18T19:00:00.000Z",
      type: "reminder",
    },
  ],
  calendarEvents: [
    {
      id: "event-may-birthday",
      title: "May Zhang 生日",
      personName: "May Zhang",
      date: "2026-05-16T09:00:00.000Z",
      type: "birthday",
      typeLabel: "生日",
      dayLabel: "5 月 16 日",
      density: 3,
      sourceId: "demo-may",
    },
    {
      id: "event-group-study",
      title: "同学小组复习",
      personName: "同学",
      date: "2026-05-18T19:00:00.000Z",
      type: "reminder",
      typeLabel: "提醒",
      dayLabel: "5 月 18 日",
      density: 2,
      sourceId: "r3",
    },
    {
      id: "event-alex-exam",
      title: "Alex 微积分期中考试",
      personName: "Alex Chen",
      date: "2026-05-20T13:00:00.000Z",
      type: "life_event",
      typeLabel: "重要节点",
      dayLabel: "5 月 20 日",
      density: 3,
      sourceId: "r2",
    },
  ],
  relationshipScores: [
    {
      personId: "demo-alex",
      personName: "Alex Chen",
      total: 86,
      freshness: 88,
      profileDepth: 92,
      milestoneCoverage: 84,
      interactionWarmth: 78,
      boundaryCare: 88,
      lifeContext: 86,
      studyCareer: 90,
      emotionalContext: 72,
      tasteMap: 88,
      playCulture: 82,
      explanation: "最近有考试和饮食偏好记录，资料很完整，适合考前发一条轻松的关心。",
      recommendation: "考前一天提醒他休息，别把关心说得太像任务。",
    },
    {
      personId: "demo-may",
      personName: "May Zhang",
      total: 90,
      freshness: 82,
      profileDepth: 94,
      milestoneCoverage: 96,
      interactionWarmth: 90,
      boundaryCare: 88,
      lifeContext: 92,
      studyCareer: 76,
      emotionalContext: 94,
      tasteMap: 96,
      playCulture: 84,
      explanation: "生日、礼物偏好和不喜欢群发祝福都记得比较清楚，适合准备有仪式感的小惊喜。",
      recommendation: "提前准备生日祝福，语气真诚一点，不要像模板。",
    },
    {
      personId: "demo-jason",
      personName: "Jason Wu",
      total: 74,
      freshness: 68,
      profileDepth: 72,
      milestoneCoverage: 78,
      interactionWarmth: 66,
      boundaryCare: 84,
      lifeContext: 72,
      studyCareer: 92,
      emotionalContext: 64,
      tasteMap: 74,
      playCulture: 70,
      explanation: "职业信息有用，但最近互动偏少，可以用一个具体问题自然重新联系。",
      recommendation: "问他 6 月入职后的节奏，顺带感谢之前的建议。",
    },
  ],
  relationshipGraph: {
    me: {
      id: "me",
      name: "Ethan Lin",
      initials: "EL",
    },
    groups: [
      { id: "group-classmates", label: "同学", color: "#256f56", memberCount: 1, orbit: 1 },
      { id: "group-home-friends", label: "老朋友", color: "#8f5a33", memberCount: 1, orbit: 2 },
      { id: "group-internship", label: "实习圈", color: "#365d8c", memberCount: 1, orbit: 3 },
    ],
    nodes: [
      {
        id: "demo-alex",
        label: "Alex Chen",
        initials: "AC",
        groupId: "group-classmates",
        groupLabel: "同学",
        score: 86,
        strength: 0.86,
        lastSignal: "5/20 微积分期中考试",
        hasUpcoming: true,
        hasBirthday: true,
        orbitIndex: 0,
      },
      {
        id: "demo-may",
        label: "May Zhang",
        initials: "MZ",
        groupId: "group-home-friends",
        groupLabel: "老朋友",
        score: 90,
        strength: 0.9,
        lastSignal: "喜欢音乐和拍立得",
        hasUpcoming: true,
        hasBirthday: true,
        orbitIndex: 1,
      },
      {
        id: "demo-jason",
        label: "Jason Wu",
        initials: "JW",
        groupId: "group-internship",
        groupLabel: "实习圈",
        score: 74,
        strength: 0.74,
        lastSignal: "6 月开始全职",
        hasUpcoming: false,
        hasBirthday: true,
        orbitIndex: 2,
      },
    ],
    edges: [
      { id: "me-demo-alex", source: "me", target: "demo-alex", label: "室友", strength: 4 },
      { id: "me-demo-may", source: "me", target: "demo-may", label: "好友", strength: 5 },
      { id: "me-demo-jason", source: "me", target: "demo-jason", label: "学长", strength: 3 },
    ],
  },
  gifts: [
    {
      id: "g1",
      title: "BYREDO 香氛礼盒",
      personName: "May Zhang",
      priceBand: "$$",
      rationale: "May 喜欢音乐、拍立得和仪式感礼物。",
    },
    {
      id: "g2",
      title: "AirPods Pro 2",
      personName: "Alex Chen",
      priceBand: "$$$",
      rationale: "Alex 通勤和自习时间多，但需要确认预算边界。",
    },
  ],
  files: [
    {
      id: "f1",
      filename: "IMG_20250512_1213.jpg",
      status: "OCR processing",
      progress: 82,
    },
    {
      id: "f2",
      filename: "Lecture_Notes_ML.pdf",
      status: "23 notes extracted",
      progress: 100,
    },
  ],
};
