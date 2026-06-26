# Memoria AI 分类与结构化输出技术报告

更新日期：2026-06-18

## 1. 报告范围

本文整理 Memoria 当前 macOS-native 阶段的 AI 分类与结构化输出设计。当前主实现目标是 macOS，本地 Swift/SQLite 工作流是事实来源；Web 端保留为视觉和 API 参考，不作为本报告的主协议依据。

本文重点覆盖：

- AI 输入如何从自由文本进入 `RawEntry`、`PendingUpdate`、`MemoryAtom`。
- `route_input` 与 `extract_memory` 的结构化 JSON 输出契约。
- 朋友档案 25 类 `PersonProfileCategory` 的 JSON Schema 枚举与分类依据。
- `MemoryAtomType`、`ReviewCategory`、`WorkspaceMode` 之间的路由关系。
- 本地 fallback 分类规则、敏感性标记与人工确认边界。

## 2. 总体结论

Memoria 的 AI 不是“自动写入数据库的分类器”，而是一个本地优先、可追溯、待确认的记忆整理器。AI 可以分类、提取、归纳、生成建议，但不能直接写入确认后的朋友档案、记忆、提醒、礼物建议或关系星图。

当前核心链路是：

```text
用户自由输入
-> 用户选择 WorkspaceMode：自我检索 / 朋友档案管理 / 行程安排
-> 保存 RawEntry 原文
-> DeepSeek extract_memory 或本地 fallback 生成结构化建议
-> 写入 PendingUpdate
-> 整理台按 ReviewCategory 展示
-> 用户批准 / 编辑 / 拒绝
-> 批准后才生成 MemoryAtom、朋友档案 patch、提醒或关系边
```

这个设计的关键点是：分类结果必须有原文证据 `source_quote`，朋友事实必须进入朋友档案相关类型，AI 推断必须标记为推断，所有最终写入都需要用户确认。

## 3. 关键模块

| 模块 | 文件 | 职责 |
| --- | --- | --- |
| AI 协议文档 | `docs/AI_CONTRACT.md` | 定义 DeepSeek、JSON 输出、`route_input`、`extract_memory` 的基本契约 |
| 记忆协议文档 | `docs/MEMORY_PROTOCOL.md` | 定义 `RawEntry`、`PendingUpdate`、`MemoryAtom` 与用户审批不变量 |
| AI workflow | `macos/Sources/MemoriaMac/Services/AIWorkflow.swift` | prompt 构造、AI JSON 解析、本地 fallback 分类与 profile patch 生成 |
| DeepSeek 客户端 | `macos/Sources/MemoriaMac/Services/LocalAI.swift` | DeepSeek 请求结构、JSON object 模式、连接测试、错误处理 |
| 协议模型 | `macos/Sources/MemoriaMac/Models/MemoryProtocolModels.swift` | `MemoryAtomType`、`ExtractMemoryResponse`、proposal 模型 |
| UI/路由模型 | `macos/Sources/MemoriaMac/Models/DashboardModels.swift` | `WorkspaceMode`、`ReviewCategory`、`PersonProfileCategory` |
| 状态编排 | `macos/Sources/MemoriaMac/Stores/DashboardStore.swift` | 捕获、约束 AI 输出、创建待审建议、批准后跳转 |
| 持久化 | `macos/Sources/MemoriaMac/Persistence/Repositories/PendingUpdateRepository.swift` | 待审建议创建、编辑、批准、拒绝与审计 |

## 4. AI 工作流设计

### 4.1 `route_input`

`route_input` 是轻量分类层，用于判断自由输入的主类型、辅助类型、是否需要提取人物、提醒或礼物线索。当前 macOS 捕获流程主要依赖用户选择的 `WorkspaceMode` 与 `extract_memory` 输出做最终约束；`route_input` 更像可验证的分类契约和未来自动路由入口。

`route_input` 不允许产生副作用，只返回 JSON object。

### 4.2 `extract_memory`

`extract_memory` 是当前核心结构化输出层。输入包括：

- `raw_entry_id`
- `raw_text`
- `known_people`
- `known_core_tags`
- 可用 workflow tool 定义
- workflow notes

输出是 `ExtractMemoryResponse`，其中包括：

- `memory_proposals`：可审核的记忆原子建议。
- `person_fact_proposals`：可审核的朋友档案字段更新建议。
- `reminder_proposals`：当前 Swift 协议里是字符串数组，占位保留。
- `gift_signal_proposals`：当前 Swift 协议里是字符串数组，占位保留。
- `conflicts`：冲突或不确定点。
- `follow_up_questions`：需要用户补充的问题。

AI 输出经过 `AIJSONParser` 与 `AIContractValidator` 后才会写入 `PendingUpdate`。校验会拒绝非法 JSON、缺少 `source_quote` 的记忆建议、缺少目标人物或值的朋友档案 patch，以及不支持的 `proposal_type`。

## 5. JSON Schema

下面是按当前 Swift 协议模型整理出的 JSON Schema。用户口中的 “Johnson Schema” 在此按 JSON Schema 理解。

### 5.1 `route_input` 输出 Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://memoria.local/schemas/route-input-result.schema.json",
  "title": "RouteInputResult",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "primary_type",
    "secondary_types",
    "confidence",
    "requires_extraction",
    "requires_person_linking",
    "requires_reminder_generation",
    "requires_gift_generation",
    "language",
    "reason_summary"
  ],
  "properties": {
    "primary_type": {
      "type": "string",
      "enum": [
        "personal_reflection",
        "idea",
        "relationship_memory",
        "person_fact",
        "event",
        "reminder_source",
        "gift_signal",
        "file_note"
      ]
    },
    "secondary_types": {
      "type": "array",
      "items": {
        "type": "string",
        "enum": [
          "personal_reflection",
          "idea",
          "relationship_memory",
          "person_fact",
          "event",
          "reminder_source",
          "gift_signal",
          "file_note"
        ]
      }
    },
    "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
    "requires_extraction": { "type": "boolean" },
    "requires_person_linking": { "type": "boolean" },
    "requires_reminder_generation": { "type": "boolean" },
    "requires_gift_generation": { "type": "boolean" },
    "language": { "type": "string", "enum": ["zh", "en", "mixed", "unknown"] },
    "reason_summary": { "type": "string", "minLength": 1 }
  }
}
```

### 5.2 `extract_memory` 输出 Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://memoria.local/schemas/extract-memory-response.schema.json",
  "title": "ExtractMemoryResponse",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "entry_summary",
    "memory_proposals",
    "person_fact_proposals",
    "reminder_proposals",
    "gift_signal_proposals",
    "conflicts",
    "follow_up_questions"
  ],
  "properties": {
    "entry_summary": { "type": "string" },
    "memory_proposals": {
      "type": "array",
      "items": { "$ref": "#/$defs/memory_atom_proposal" }
    },
    "person_fact_proposals": {
      "type": "array",
      "items": { "$ref": "#/$defs/person_profile_patch_proposal" }
    },
    "reminder_proposals": {
      "type": "array",
      "items": { "type": "string" }
    },
    "gift_signal_proposals": {
      "type": "array",
      "items": { "type": "string" }
    },
    "conflicts": {
      "type": "array",
      "items": { "type": "string" }
    },
    "follow_up_questions": {
      "type": "array",
      "items": { "type": "string" }
    }
  },
  "$defs": {
    "memory_atom_type": {
      "type": "string",
      "enum": [
        "personal_reflection",
        "idea",
        "relationship_memory",
        "person_fact",
        "event",
        "reminder_source",
        "gift_signal",
        "file_note"
      ]
    },
    "sensitivity": {
      "type": "string",
      "enum": ["normal", "private", "sensitive"]
    },
    "profile_category": {
      "type": "string",
      "enum": [
        "identity",
        "contact",
        "relationship",
        "education",
        "career",
        "family",
        "friend_network",
        "interests",
        "media",
        "food_preference",
        "dietary_allergy",
        "travel_preference",
        "style_aesthetic",
        "spending_preference",
        "gift_history",
        "lifestyle",
        "current_state",
        "life_events",
        "emotional_preference",
        "communication_preference",
        "taboo_boundary",
        "anniversaries",
        "reminders",
        "files",
        "ai_inference"
      ]
    },
    "related_person_proposal": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "display_name",
        "match_confidence",
        "relation_type"
      ],
      "properties": {
        "display_name": { "type": "string", "minLength": 1 },
        "matched_person_id": { "type": ["string", "null"] },
        "match_confidence": { "type": "number", "minimum": 0, "maximum": 1 },
        "relation_type": { "type": "string", "minLength": 1 }
      }
    },
    "theme_proposal": {
      "type": "object",
      "additionalProperties": false,
      "required": ["name", "confidence"],
      "properties": {
        "name": { "type": "string", "minLength": 1 },
        "confidence": { "type": "number", "minimum": 0, "maximum": 1 }
      }
    },
    "relationship_edge_proposal": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "source_display_name",
        "target_display_name",
        "label",
        "strength",
        "relation_kind",
        "tags",
        "confidence",
        "is_ai_inferred",
        "source_quote"
      ],
      "properties": {
        "source_person_id": { "type": ["string", "null"] },
        "source_display_name": { "type": "string", "minLength": 1 },
        "target_person_id": { "type": ["string", "null"] },
        "target_display_name": { "type": "string", "minLength": 1 },
        "label": { "type": "string", "minLength": 1 },
        "strength": { "type": "number", "minimum": 0, "maximum": 1 },
        "relation_kind": { "type": "string", "minLength": 1 },
        "tags": {
          "type": "array",
          "items": { "type": "string", "minLength": 1 }
        },
        "ai_primary_tag": { "type": ["string", "null"] },
        "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
        "is_ai_inferred": { "type": "boolean" },
        "source_quote": { "type": "string", "minLength": 1 }
      }
    },
    "memory_atom_proposal": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "proposal_type",
        "memory_type",
        "title",
        "summary",
        "content",
        "source_quote",
        "confidence",
        "sensitivity",
        "is_ai_inferred",
        "related_people",
        "themes",
        "follow_up_questions",
        "suggested_actions"
      ],
      "properties": {
        "proposal_type": { "const": "memory_atom" },
        "memory_type": { "$ref": "#/$defs/memory_atom_type" },
        "title": { "type": "string", "minLength": 1 },
        "summary": { "type": "string" },
        "content": { "type": "string" },
        "source_quote": { "type": "string", "minLength": 1 },
        "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
        "sensitivity": { "$ref": "#/$defs/sensitivity" },
        "is_ai_inferred": { "type": "boolean" },
        "related_people": {
          "type": "array",
          "items": { "$ref": "#/$defs/related_person_proposal" }
        },
        "themes": {
          "type": "array",
          "items": { "$ref": "#/$defs/theme_proposal" }
        },
        "relationship_edge_proposals": {
          "type": "array",
          "items": { "$ref": "#/$defs/relationship_edge_proposal" }
        },
        "follow_up_questions": {
          "type": "array",
          "items": { "type": "string" }
        },
        "suggested_actions": {
          "type": "array",
          "items": { "type": "string" }
        }
      }
    },
    "person_profile_patch_proposal": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "target_display_name",
        "profile_category",
        "proposed_value",
        "source_quote",
        "confidence",
        "sensitivity",
        "is_ai_inferred",
        "merge_strategy"
      ],
      "anyOf": [
        {
          "required": ["target_person_id"],
          "properties": {
            "target_person_id": { "type": "string", "minLength": 1 }
          }
        },
        {
          "properties": {
            "target_display_name": { "type": "string", "minLength": 1 }
          }
        }
      ],
      "properties": {
        "target_person_id": { "type": ["string", "null"] },
        "target_display_name": { "type": "string" },
        "profile_category": { "$ref": "#/$defs/profile_category" },
        "proposed_value": { "type": "string", "minLength": 1 },
        "source_quote": { "type": "string", "minLength": 1 },
        "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
        "sensitivity": { "$ref": "#/$defs/sensitivity" },
        "is_ai_inferred": { "type": "boolean" },
        "merge_strategy": { "const": "append_unique" }
      }
    }
  }
}
```

说明：Swift `JSONDecoder` 默认会忽略额外字段，所以上面的 `additionalProperties: false` 是推荐的协议硬约束，而不是当前运行时已完全强制的全部约束。当前运行时已经强制的关键约束是：JSON 必须可解析、`memory_proposals[].proposal_type` 必须是 `memory_atom`、记忆与档案 patch 必须有 `source_quote`，朋友档案 patch 必须有目标人物和 `proposed_value`。

## 6. 分类依据

### 6.1 顶层记忆类型 `MemoryAtomType`

| `memory_type` | 中文含义 | 分类依据 | 默认整理台分区 |
| --- | --- | --- | --- |
| `personal_reflection` | 自我想法 | 用户表达自己的情绪、习惯、边界、价值判断、关系中的自我感受。例如“我好像总是怕麻烦别人”。 | 自我检索 |
| `idea` | 想法/灵感 | 创意、计划、观点、灵感，但不直接对应朋友事实或提醒。 | 自我检索 |
| `relationship_memory` | 关系记忆 | 描述与某个人或多个人之间的互动、关系变化、共同经历、社交网络。可附带 `relationship_edge_proposals`。 | 朋友档案管理 |
| `person_fact` | 朋友事实 | 关于某个朋友的明确事实或偏好，例如喜欢吃什么、不吃什么、生日、学校、公司、兴趣。 | 朋友档案管理 |
| `event` | 事件 | 已发生或将发生的重要事件。若包含日期、提醒、考试、面试、约见等行程信号，路由到行程安排；否则进入自我检索。 | 视内容而定 |
| `reminder_source` | 提醒线索 | 明确包含提醒、deadline、due、别忘、下周、明天、考试、面试、见面等行动或时间信号。 | 行程安排 |
| `gift_signal` | 礼物线索 | 表达礼物、送礼、偏好、愿望清单、适合送什么、踩雷记录等线索。 | 朋友档案管理 |
| `file_note` | 文件备注 | 从文件、导入材料、截图、PDF/文本中提取出的备注或来源说明。 | 自我检索 |

### 6.2 本地 fallback 优先级

当没有 DeepSeek API key，或远端 AI 失败时，`AIWorkflowService` 会用 deterministic fallback 生成本地草稿。当前优先级是：

1. 包含 `礼物`、`gift`、`present`：归为 `gift_signal`。
2. 包含 `提醒`、`别忘`、`remind`、`deadline`、`due`：归为 `reminder_source`。
3. 匹配已知人物，并且像朋友事实：归为 `person_fact`。
4. 匹配已知人物，并且包含关系词：归为 `relationship_memory`。
5. 其他情况：归为 `personal_reflection`。

这条优先级修复了一个关键误分类风险：例如“Alex Chen 喜欢吃薯片”必须是朋友事实或朋友档案 patch，不能被错误写成“我害怕在人际交往中麻烦别人”一类的自我反思。

### 6.3 朋友档案 25 类分类依据

朋友档案字段必须使用以下 `profile_category`。这些 key 同时用于 AI 输出、SQLite `category_notes_json` 和朋友详情页手动编辑。

| `profile_category` | 中文名 | 典型分类依据 |
| --- | --- | --- |
| `identity` | 身份信息 | 姓名、昵称、英文名、头像、生日、年龄段、星座、MBTI、城市、家乡、语言 |
| `contact` | 联系方式 | 微信、电话、邮箱、Instagram、小红书、LinkedIn、常用联系渠道 |
| `relationship` | 关系信息 | 认识时间、认识地点、认识方式、共同朋友、亲近等级、关系标签、边界 |
| `education` | 教育经历 | 学校、专业、年级、课程、导师、社团、交换经历、毕业时间 |
| `career` | 职业经历 | 公司、岗位、行业、实习、项目、求职方向、简历、面试、职业目标 |
| `family` | 家庭关系 | 父母、兄弟姐妹、伴侣、宠物、家庭城市、重要家庭事件 |
| `friend_network` | 朋友网络 | 共同好友、朋友圈层、和谁关系好、和谁有矛盾、社交偏好 |
| `interests` | 兴趣爱好 | 阅读、电影、剧集、音乐、运动、游戏、手工、摄影、艺术、博物馆 |
| `media` | 书影音 | 喜欢的书、正在读的书、喜欢的作者、电影导演、歌手、播客、YouTube 频道 |
| `food_preference` | 饮食偏好 | 喜欢的菜系、餐厅、饮料、咖啡、茶、甜品、辣度、酒精偏好 |
| `dietary_allergy` | 忌口过敏 | 不吃什么、过敏源、宗教饮食限制、健康饮食要求 |
| `travel_preference` | 旅行偏好 | 想去城市、去过城市、旅行方式、预算、酒店偏好、喜欢自然还是城市 |
| `style_aesthetic` | 穿搭审美 | 喜欢颜色、品牌、风格、尺码、首饰偏好、香水偏好 |
| `spending_preference` | 消费偏好 | 喜欢实用礼物还是仪式感礼物、喜欢大牌还是小众、是否介意二手 |
| `gift_history` | 礼物历史 | 你送过什么、对方反应、别人送过什么、踩雷记录、愿望清单 |
| `lifestyle` | 生活习惯 | 作息、运动、睡眠、通勤、居住状态、是否养宠物、是否做饭 |
| `current_state` | 当前状态 | 最近压力、最近开心的事、最近烦恼、近期目标、正在准备的事情 |
| `life_events` | 人生大事 | 升学、毕业、搬家、换工作、分手、恋爱、结婚、比赛、旅行、手术、考试 |
| `emotional_preference` | 情绪偏好 | 喜欢被怎么安慰、讨厌什么安慰方式、是否喜欢惊喜、是否需要空间 |
| `communication_preference` | 沟通偏好 | 喜欢文字还是语音、回复频率、是否讨厌电话、适合深聊还是轻松聊天 |
| `taboo_boundary` | 禁区边界 | 不该提的话题、不喜欢的玩笑、不想被评价的事情、隐私边界 |
| `anniversaries` | 纪念日 | 生日、认识纪念日、毕业日、重要考试、工作入职日、宠物生日 |
| `reminders` | 提醒事项 | 生日礼物、问候、考试祝福、旅行前提醒、面试前鼓励、术后关心 |
| `files` | 文件资料 | 简历、作品集、聊天截图、照片、PDF、语音转写、手写备注 |
| `ai_inference` | AI 推断 | 可能喜欢的风格、可能适合的礼物、可能的关系变化；必须标记为推断 |

分类时应遵守一条硬规则：原文明确表达的朋友事实进入对应事实类；AI 推测只能进入 `ai_inference`，并设置 `is_ai_inferred: true`。

### 6.4 `WorkspaceMode` 与 `ReviewCategory`

用户在 `记录` 页面必须先选择一个 `WorkspaceMode`：

| `WorkspaceMode` | 中文入口 | 对应 `ReviewCategory` | 目标 |
| --- | --- | --- | --- |
| `selfSearch` | 自我检索 | `selfSearch` | 管理自我反思、核心标签、个人时间线 |
| `friendDossier` | 朋友档案管理 | `friendDossier` | 管理朋友档案、关系记忆、礼物线索、关系星图建议 |
| `schedule` | 行程安排 | `schedule` | 管理提醒、日期、考试、面试、约见、生日与待办 |

模型输出不会绕开这个用户选择。`DashboardStore` 会在写入 `PendingUpdate` 前对输出做二次约束：

- 行程模式：如果 AI 没有生成记忆建议，则创建 `reminder_source` fallback；如果生成了其他类型，会转成 `reminder_source`；同时丢弃朋友档案 patch。
- 朋友档案模式：保留朋友档案 patch；如果同一条朋友事实已经作为 profile patch 出现，会去掉重复的 `person_fact` 记忆建议。
- 自我检索模式：保留 AI 输出，但最终仍需整理台审批。

`PendingUpdate.reviewCategory` 还会根据 proposal 类型推断显示分区：

```text
personal_reflection / idea / file_note -> selfSearch
relationship_memory / person_fact / gift_signal -> friendDossier
reminder_source -> schedule
event + schedule signals -> schedule
event without schedule signals -> selfSearch
person_profile_patch -> friendDossier
```

### 6.5 敏感性与推断标记

`sensitivity` 有三个值：

| 值 | 用途 |
| --- | --- |
| `normal` | 普通朋友事实、普通关系记录、一般提醒 |
| `private` | 用户自己的反思、自我感受、默认不适合公开检索的内容 |
| `sensitive` | 心理、健康、家庭、财务、恋爱、政治等高敏感内容 |

`is_ai_inferred` 表示该字段是否是 AI 推断：

- 明确来自原文的事实：`false`。
- 根据偏好、关系变化、风格、礼物方向推测出的建议：`true`。
- AI 推断不能写入普通事实类，必须进入 `ai_inference` 或以待审建议存在。

## 7. 输出示例

### 7.1 自我反思

输入：

```text
我好像总是怕麻烦 Alex，所以很多事情没说。
```

输出重点：

```json
{
  "memory_type": "personal_reflection",
  "title": "我在人际关系里害怕麻烦别人",
  "source_quote": "我好像总是怕麻烦 Alex，所以很多事情没说。",
  "sensitivity": "private",
  "related_people": [
    {
      "display_name": "Alex",
      "matched_person_id": "demo-alex",
      "match_confidence": 0.91,
      "relation_type": "about"
    }
  ]
}
```

分类依据：主语是“我”，内容是用户对自身关系模式的反思，因此进入 `personal_reflection`，并默认标记为 `private`。

### 7.2 朋友事实

输入：

```text
我记得 Alex Chen 喜欢吃火锅，不吃香菜。
```

输出重点：

```json
{
  "person_fact_proposals": [
    {
      "target_person_id": "demo-alex",
      "target_display_name": "Alex Chen",
      "profile_category": "food_preference",
      "proposed_value": "喜欢吃火锅",
      "source_quote": "我记得 Alex Chen 喜欢吃火锅，不吃香菜。",
      "confidence": 0.88,
      "sensitivity": "normal",
      "is_ai_inferred": false,
      "merge_strategy": "append_unique"
    },
    {
      "target_person_id": "demo-alex",
      "target_display_name": "Alex Chen",
      "profile_category": "dietary_allergy",
      "proposed_value": "不吃香菜",
      "source_quote": "我记得 Alex Chen 喜欢吃火锅，不吃香菜。",
      "confidence": 0.9,
      "sensitivity": "normal",
      "is_ai_inferred": false,
      "merge_strategy": "append_unique"
    }
  ]
}
```

分类依据：主语是 Alex Chen，内容是明确偏好和忌口，分别进入 `food_preference` 与 `dietary_allergy`。这类内容不能降级成用户自我反思。

### 7.3 关系边建议

输入：

```text
May 说 Alex 最近经常问她 class project 的材料。
```

输出重点：

```json
{
  "memory_type": "relationship_memory",
  "relationship_edge_proposals": [
    {
      "source_person_id": "demo-may",
      "source_display_name": "May Zhang",
      "target_person_id": "demo-alex",
      "target_display_name": "Alex Chen",
      "label": "课程项目弱连接",
      "strength": 0.58,
      "relation_kind": "project",
      "tags": ["项目伙伴", "弱连接"],
      "ai_primary_tag": "项目伙伴",
      "confidence": 0.82,
      "is_ai_inferred": true,
      "source_quote": "May 说 Alex 最近经常问她 class project 的材料。"
    }
  ]
}
```

分类依据：原文明确支持 May 与 Alex 之间存在项目材料交流，因此可以提出关系边建议。但 AI 不能直接改变手动亲近等级 `manual_closeness_level`，只能生成待审关系边。

## 8. 安全与可靠性约束

1. DeepSeek API key 只存 macOS Keychain，不写入 SQLite、文档、日志、fixture 或源码。
2. AI 只能创建 `PendingUpdate`，不能直接写确认后的 `MemoryAtom`、朋友档案、提醒、礼物或关系边。
3. 每条可入库记忆必须有 `source_quote` 或 `source_entry_id`。
4. 朋友档案 patch 必须有目标人物和 `proposed_value`。
5. AI 推断必须显式标记 `is_ai_inferred: true`。
6. 敏感内容需要标记 `private` 或 `sensitive`，并避免默认搜索暴露。
7. 用户批准是最终写入的事务签名。
8. 远端 AI 失败时，原文 `RawEntry` 仍保留，本地 fallback 生成可审核草稿。

## 9. 当前验证方式

当前 macOS 行为变更的推荐验证命令是：

```bash
cd macos
swift run MemoriaProtocolChecks
swift build

cd ..
bash ./script/build_and_run.sh --verify
```

`MemoriaProtocolChecks` 已覆盖：

- AI JSON parser 接受合法响应、拒绝非法响应。
- 连接测试必须是最小 JSON ping，不能误用完整抽取 schema。
- 朋友饮食偏好不能被归成自我反思。
- 本地 fallback 能生成朋友档案 patch。
- 非法 profile category、空 source quote、缺少目标人物的 patch 会被拒绝。
- 关系边建议批准后才写入关系星图。
- `PendingUpdate` 会路由到三种整理台分区。
- 行程模式会强制进入行程整理分区并创建 reminder 相关记忆。
- 25 类朋友档案字段支撑 AI schema。

## 10. 已知限制与改进建议

1. 当前 JSON Schema 主要由 Swift 类型和 prompt 契约推导；运行时校验还不是完整 JSON Schema validator。建议后续引入显式 schema 校验，减少 prompt 与模型漂移。
2. `reminder_proposals` 与 `gift_signal_proposals` 当前在 Swift 协议里还是字符串数组。后续如果要让 AI 直接提出结构化提醒或礼物建议，应升级为对象数组，并补充日期、人物、风险、分数和确认问题字段。
3. `route_input` 当前不是捕获链路的唯一分类入口。实际产品路由以用户选择的 `WorkspaceMode`、`extract_memory` 输出和 `DashboardStore.constrained` 二次约束为准。
4. `additionalProperties: false` 目前是推荐协议而不是 Swift 解码器强制行为。如果要严格阻断额外字段，需要自定义解码或引入 JSON Schema 校验。
5. Web 端 `src/lib/local-ai.ts` 仍使用旧的 `people/reminders/giftIdeas` 简化抽取结构，应继续视作参考层，避免和 macOS 主协议混用。

## 11. 一句话总结

Memoria 当前 AI 分类设计的核心不是“让模型自动决定并写入”，而是“让模型提出有证据、可分类、可审核的结构化建议”；朋友事实、关系观察、自我反思、行程提醒和礼物线索分别进入不同 schema 与整理台分区，最终由用户批准后才成为本地可信记忆。
