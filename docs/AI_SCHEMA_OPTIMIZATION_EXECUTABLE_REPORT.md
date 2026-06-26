# Memoria AI Schema 优化可执行报告

来源报告：`/Users/zaozaowang/Downloads/deep-research-report.md`

生成日期：2026-06-19

## 0. 执行结论

这份优化可以执行，但必须按 macOS 本地优先的现有协议分阶段落地。当前阶段不做 provider 迁移、不改 SQLite schema、不跳过整理台、不让 AI 直接写最终事实。

最终执行目标是：

- AI 输出更稳定：`extract_memory` 输出带版本、证据、结构化提醒/礼物线索。
- 用户更放心：整理台能显示“来自哪句话、为什么这样分类、将写入哪里、是事实还是推断、风险是什么、错了怎么改”。
- 工程更安全：v1.0 输出继续可读，v1.1 输出可验证，失败时保留 `RawEntry` 并进入本地 fallback。

本报告已经吸收三类独立盲审意见：

| 盲审角色 | 第一轮分数 | 主要问题 | 已整合到本报告 |
| --- | ---: | --- | --- |
| 资深软件开发者 | 88 | reminder/gift 落地路径、严格校验范围、回滚边界不够清楚 | 增加硬边界、严格 key validator、v1.1 解码策略、mapping 和回滚规则 |
| 高社交需求用户 | 86 | 快速纠错、同名/昵称、生日忌口联系方式、礼物风险不够具体 | 增加纠错闭环、最小 `value_struct`、候选人物、社交风险枚举、批量规则 |
| 前端/视觉设计师 | 82 | 整理台 UI contract、信息层级、microcopy、可访问性和视觉 QA 不够 | 增加整理台 UI contract、卡片字段顺序、状态文案、Quiet Premium 与 QA |

## 1. 硬边界

以下内容在本阶段明确不执行：

- 不引入 OpenAI / Anthropic SDK，不迁移 provider。
- 不在 macOS runtime 引入 Ajv、Python `jsonschema` 或其他 JSON Schema 第三方依赖。
- 不修改 SQLite schema；`schema_version`、结构化提醒、结构化礼物线索和撤销锚点先保存在 `pending_updates.payload_json` 的兼容 envelope。
- 不新增 `PendingUpdateStatus`；已批准项撤销时不能把 approved 记录无审计地改回 pending。
- 不绕过 `RawEntry -> PendingUpdate -> 整理台 -> 用户批准 -> MemoryAtom`。
- 不让 AI 自动改变 `manual_closeness_level`。
- 不自动联网验证朋友事实。
- 不扩展 iOS、Android、Windows。
- 不把 AI 推断写成确认事实；推断必须标记，并由用户确认。

## 2. 可执行性判断

| 原报告建议 | 执行结论 | 本项目执行方式 |
| --- | --- | --- |
| Generation Schema + Canonical Schema | 执行 | 新增本地 schema 文件；Generation 给 prompt/fixtures 用，Canonical 给 Swift 校验和文档用 |
| `additionalProperties: false` | 执行为 Swift 严格 key 检测 | P0 用 `JSONSerialization` 做 top-level 和已知嵌套对象 key 检测，不引入 schema runtime |
| `schema_version`、`contract_name` | 执行且兼容 | v1.0 缺失视为旧协议；未知版本 fail closed |
| `reminder_proposals` 结构化 | 执行 | P1 解析结构化 proposal，但映射为 `.reminderSource` 的待审 `MemoryAtomProposal`，不新增直接落库路径 |
| `gift_signal_proposals` 结构化 | 执行 | P1 解析礼物线索，映射为 `.giftSignal` 待审记忆，不直接生成最终 `GiftIdea` |
| `value_struct` | 执行最小集 | P1 只覆盖生日/纪念日、忌口过敏、联系方式；仍保留 `proposed_value` 文本 |
| OpenAI Structured Outputs / Anthropic strict tools | 不执行 | 只吸收严格输出原则，当前仍使用 DeepSeek `response_format: {"type":"json_object"}` |
| Ajv / Python `jsonschema` | 不进入 app runtime | 可用于本地文档校验脚本，但不是产品依赖 |
| 数据库迁移存版本列 | 暂不执行 | payload 内版本足够，避免迁移风险 |

## 3. 协议目标状态

### 3.1 v1.0 兼容

现有 fixture 和真实输出仍有效：

```json
{
  "entry_summary": "用户反思自己和 Alex 的关系中可能害怕麻烦对方。",
  "memory_proposals": [],
  "person_fact_proposals": [],
  "reminder_proposals": [],
  "gift_signal_proposals": [],
  "conflicts": [],
  "follow_up_questions": []
}
```

缺少 `schema_version` 和 `contract_name` 时，Swift 解码器视为 `extract_memory v1.0`。

### 3.2 v1.1 增强

v1.1 输出应包含：

- `schema_version: "1.1"`
- `contract_name: "extract_memory"`
- 结构化 `reminder_proposals`
- 结构化 `gift_signal_proposals`
- 可选证据定位：`source_entry_id`、`source_quote_start`、`source_quote_end`
- 可选最小 `value_struct`，只用于生日/纪念日、忌口过敏、联系方式

未知版本或错误 `contract_name` 必须 fail closed：保留 `RawEntry`，不写 `PendingUpdate`，UI 显示 AI 输出结构不可用，并允许本地 fallback。

## 4. P0：契约冻结与严格校验

P0 的目标是先让现有协议“可验证、可回归、可拒绝明显脏输出”，不改变 UI 主流程和数据库。

### Task P0.1：更新权威文档

**文件**

- 修改：`docs/AI_CONTRACT.md`
- 修改：`docs/MEMORY_PROTOCOL.md`
- 修改：`docs/deepseek-api-interface.md`

**动作**

- 在 `AI_CONTRACT.md` 中标注当前 baseline 为 `extract_memory v1.0`。
- 增加 v1.1 兼容规则：缺版本按 v1.0，未知版本 fail closed。
- 写清 DeepSeek 仍使用 `/chat/completions` 与 `response_format: {"type":"json_object"}`。
- 在 `MEMORY_PROTOCOL.md` 增加：版本和结构化 proposal 暂存在 `payload_json`，不新增 SQLite 列。

**验收**

- 文档中明确出现“不改 provider、不改 DB、不绕过整理台”。
- 文档中明确 `RawEntry` 在 AI 失败时仍然保留。

### Task P0.2：新增 schema 文件

**文件**

- 新增：`docs/schemas/extract-memory.generation.v1.1.schema.json`
- 新增：`docs/schemas/extract-memory.canonical.v1.1.schema.json`

**动作**

- `generation` schema 只用稳定子集：`object`、`array`、`enum`、`const`、`required`、`additionalProperties: false`、`["string","null"]`。
- `canonical` schema 可记录更强语义：证据定位、风险枚举、最小 `value_struct`、未知版本拒绝。
- enum 必须和 Swift 一致：
  - `MemoryAtomType`
  - `MemorySensitivity`
  - `PersonProfileCategory`
  - `ProfilePatchMergeStrategy`

**验收**

```bash
node -e 'JSON.parse(require("fs").readFileSync("docs/schemas/extract-memory.generation.v1.1.schema.json","utf8")); JSON.parse(require("fs").readFileSync("docs/schemas/extract-memory.canonical.v1.1.schema.json","utf8")); console.log("schemas parse")'
```

预期：输出 `schemas parse`。

### Task P0.3：实现 Swift 严格 key validator

**文件**

- 修改：`macos/Sources/MemoriaMac/Services/AIWorkflow.swift`
- 修改：`macos/Sources/MemoriaMac/Models/MemoryProtocolModels.swift`
- 修改：`macos/Tests/MemoriaProtocolChecks/main.swift`
- 新增：`macos/Tests/Fixtures/extract_memory_extra_top_level_key.json`
- 新增：`macos/Tests/Fixtures/extract_memory_extra_nested_key.json`
- 新增：`macos/Tests/Fixtures/extract_memory_confidence_out_of_range.json`

**动作**

- 在 `AIJSONParser.parseExtractMemoryResponse(data:)` 解码前，使用 `JSONSerialization` 做轻量严格检查。
- P0 必须拒绝：
  - top-level 未知 key
  - `memory_proposals[]` 未知 key
  - `person_fact_proposals[]` 未知 key
  - `related_people[]` 未知 key
  - `themes[]` 未知 key
  - `memory_proposals[].relationship_edge_proposals[]` 未知 key；这是现有 `MemoryAtomProposal` 内部字段，不新增顶层 proposal 类型
  - `confidence` 原始值 `< 0` 或 `> 1`
  - 缺 `source_quote`
  - 空 target person
  - 非法 enum
- P0 不要求完整 Draft 2020-12 validator。

**验收**

`MemoriaProtocolChecks` 新增断言：

- v1.0 valid fixture 通过。
- extra top-level key 被拒绝。
- extra nested key 被拒绝。
- confidence 越界被拒绝，不能被 Swift init clamp 掩盖。
- 空 `source_quote` 被拒绝。
- profile category 非法被拒绝。
- `relationship_edge_proposals` 只能出现在 `memory_proposals[]` 内部；顶层同名字段必须被拒绝。

## 5. P1：v1.1 结构化 proposal 与社交纠错闭环

P1 的目标是让提醒、礼物线索和高价值朋友事实结构化，但仍然经过 `PendingUpdate` 和整理台。

### Task P1.1：扩展 v1.1 解码模型

**文件**

- 修改：`macos/Sources/MemoriaMac/Models/MemoryProtocolModels.swift`
- 修改：`macos/Sources/MemoriaMac/Services/AIWorkflow.swift`
- 新增：`macos/Tests/Fixtures/extract_memory_v11_structured_schedule_gift.json`
- 新增：`macos/Tests/Fixtures/extract_memory_v11_unknown_version.json`

**动作**

- `ExtractMemoryResponse` 增加：
  - `schemaVersion: String?`
  - `contractName: String?`
- 缺失版本：按 v1.0。
- `schema_version == "1.1"` 且 `contract_name == "extract_memory"`：按 v1.1。
- 其他版本或 contract：fail closed。

新增 `ReminderProposal`：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `proposal_id` | `String` | 模型生成的稳定局部 id；不作为数据库主键 |
| `title` | `String` | 提醒标题 |
| `target_person_id` | `String?` | 可空，需用户确认 |
| `target_display_name` | `String?` | 原文人物名 |
| `candidate_person_ids` | `[String]` | 同名/昵称候选 |
| `due_at` | `String?` | ISO 日期时间；不确定必须为 null |
| `due_label` | `String` | 原文时间表达，如“下周三” |
| `source_entry_id` | `String?` | 可选来源 |
| `source_quote` | `String` | 必填 |
| `source_quote_start` / `source_quote_end` | `Int?` | 可选偏移 |
| `confidence` | `Double` | 0...1 |
| `is_ai_inferred` | `Bool` | 推断标记 |
| `legacy_text` | `String` | 兼容旧显示 |

新增 `GiftSignalProposal`：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `proposal_id` | `String` | 局部 id |
| `target_person_id` | `String?` | 可空 |
| `target_display_name` | `String?` | 原文人物名 |
| `candidate_person_ids` | `[String]` | 同名/昵称候选 |
| `signal_summary` | `String` | 礼物线索摘要 |
| `occasion` | `String?` | birthday、graduation、visit、comfort、unknown 等 |
| `budget_hint` | `String?` | 原文预算，不确定为 null |
| `risk_tags` | `[GiftSocialRisk]` | 见 Task P1.3 |
| `risk` | `String` | 人类可读风险 |
| `confirmation_question` | `String` | 批准前要问用户的问题 |
| `source_quote` | `String` | 必填 |
| `source_quote_start` / `source_quote_end` | `Int?` | 可选偏移 |
| `confidence` | `Double` | 0...1 |
| `is_ai_inferred` | `Bool` | 推断标记 |
| `legacy_text` | `String` | 兼容旧显示 |

**验收**

- v1.0 fixture 仍通过。
- v1.1 fixture 能解析结构化 reminder/gift。
- unknown version fixture 被拒绝。

**v1.1 validator 覆盖矩阵**

P1 新增对象必须接入与 P0 同一套 fail-closed validator，不能只做 Codable 解码：

| 对象 | 必须拒绝 |
| --- | --- |
| `reminder_proposals[]` | 未知 key、空 `source_quote`、`confidence` 越界、非法 `due_at` 类型、`candidate_person_ids` 非数组、`target_person_id` 与候选不一致 |
| `gift_signal_proposals[]` | 未知 key、空 `source_quote`、`confidence` 越界、非法 `risk_tags`、空 `confirmation_question`、`candidate_person_ids` 非数组 |
| `value_struct.anniversaries` | 非法 `kind`、非数字 `month/day/year`、无法确认却填了确定生日、缺 `date_label` |
| `value_struct.dietary_allergy` | 非法 `kind`、空 `item`、非法 `severity`、把 dislike 写成 allergy 且无证据 |
| `value_struct.contact` | 非法 `channel`、空 `value`、非法 `visibility` |

新增 fixtures：

- `extract_memory_v11_bad_reminder_unknown_key.json`
- `extract_memory_v11_bad_gift_risk_tag.json`
- `extract_memory_v11_bad_value_struct_anniversary.json`
- `extract_memory_v11_bad_candidate_person_ids.json`

### Task P1.2：定义结构化 reminder/gift 的落地路径

**文件**

- 修改：`macos/Sources/MemoriaMac/Models/DashboardModels.swift`
- 修改：`macos/Sources/MemoriaMac/Stores/DashboardStore.swift`
- 修改：`macos/Sources/MemoriaMac/Persistence/Repositories/PendingUpdateRepository.swift`
- 修改：`macos/Tests/MemoriaProtocolChecks/main.swift`

**硬规则**

- 不新增 `PendingProposalType` 作为 P1 默认路径。
- 不让 `ReminderProposal` 直接写 `reminders`。
- 不让 `GiftSignalProposal` 直接写 `gift_ideas`。
- 不把结构化字段直接塞进现有 `MemoryAtomProposal` 未声明 key；否则严格 validator 和 Codable 解码会互相打架。

**`payload_json` 兼容 envelope**

当前代码会把 `PendingUpdate.payloadJSON` 直接解成 `MemoryAtomProposal` 或 `PersonProfilePatchProposal`。P1 必须先新增兼容解码 helper：

- `PendingUpdate.memoryAtomProposalForReview()`：先尝试直接解 `MemoryAtomProposal`；失败后解 `PendingUpdatePayloadEnvelope`，再读取 `proposal`。
- `PendingUpdate.profilePatchProposalForReview()`：先尝试直接解 `PersonProfilePatchProposal`；失败后解 envelope 内的 `proposal`。
- `PendingUpdate.structuredReviewContext`：只从 envelope 读取，不影响旧 payload。
- `PendingUpdateRepository.approve(id:)` 和 `approvePersonProfilePatch(_:)` 必须改用上述 helper，不能继续直接 `decoder.decode(..., from: update.payloadJSON)`。
- `PendingUpdateRepository.edit(...)` 必须支持 envelope：编辑时更新 envelope 内 `proposal`，同时保留 `structured_context`、`review_explanation`、`freshness`、`approval_result` 和 `undo`；legacy direct payload 仍按旧路径编辑。

envelope 顶层字段固定如下，未知 key 必须被测试拒绝：

```json
{
  "payload_schema_version": "1.1",
  "payload_contract_name": "pending_update_payload",
  "proposal_kind": "memory_atom",
  "proposal": {
    "proposal_type": "memory_atom",
    "memory_type": "reminder_source",
    "title": "提醒 Jason 内推材料",
    "summary": "下周三提醒用户问 Jason 内推材料。",
    "content": "下周三提醒用户问 Jason 内推材料。",
    "source_quote": "下周三提醒我问 Jason 内推材料",
    "confidence": 0.91,
    "sensitivity": "normal",
    "is_ai_inferred": false,
    "related_people": [],
    "themes": [],
    "relationship_edge_proposals": null,
    "follow_up_questions": [],
    "suggested_actions": []
  },
  "structured_context": {
    "source_kind": "reminder_proposal",
    "source_proposal_id": "rp-1",
    "reminder": {
      "title": "问 Jason 内推材料",
      "target_person_id": null,
      "target_display_name": "Jason",
      "candidate_person_ids": [],
      "due_at": null,
      "due_label": "下周三",
      "date_parse_reason": "原文只有相对日期，批准前需要用户确认具体日期"
    },
    "gift_signal": null,
    "value_struct": null
  },
  "review_explanation": {
    "target_match_reason": "原文出现 Jason，但本地候选不唯一或尚未匹配",
    "category_reason": "句子包含提醒动作，因此进入行程安排",
    "date_parse_reason": "原文为相对日期，不能静默写成永久日期",
    "risk_reason": "未发现送礼或关系敏感风险",
    "confidence_reason": "动作和对象明确，日期需要确认"
  },
  "freshness": {
    "effective_status": "current",
    "last_observed": "2026-06-19",
    "staleness_reason": null,
    "supersedes_memory_id": null
  },
  "approval_result": null,
  "undo": null
}
```

`proposal` 必须始终是现有 Codable proposal 的完整副本；UI 和批准路径先使用它保证旧链路可工作。`structured_context` 只增强整理台编辑、解释、日期确认和礼物风险，不是新的落库入口。

**mapping**

- `ReminderProposal` 投影成待审 `MemoryAtomProposal(memoryType: .reminderSource)`。
- `GiftSignalProposal` 投影成待审 `MemoryAtomProposal(memoryType: .giftSignal)`。
- 批准 `.reminderSource` 后，继续走现有 `createReminderIfApproved` 派生 reminder。
- 批准 `.giftSignal` 后，只写确认记忆；后续礼物推荐仍由用户在朋友详情页触发。

**验收**

- schedule 模式下，结构化提醒进入 `行程安排`。
- gift signal 进入 `朋友档案管理`，不直接生成最终礼物推荐。
- 批准前没有新增 `reminders` 或 `gift_ideas`。
- 批准后 `.reminderSource` 才生成 reminder。
- legacy 直接 payload 和 v1.1 envelope payload 都能在整理台显示、编辑、批准。
- envelope 未知 key、缺 `proposal`、`proposal_kind` 与 `proposal_type` 不一致都必须 fail closed。
- legacy v1.0 fixture 必须覆盖非空 `reminder_proposals` 或 `gift_signal_proposals` 的旧输出，防止 v1.1 结构体数组改造误伤真实旧响应。

### Task P1.3：最小 `value_struct` 与社交风险枚举

**文件**

- 修改：`macos/Sources/MemoriaMac/Models/MemoryProtocolModels.swift`
- 修改：`macos/Sources/MemoriaMac/Persistence/LocalSQLiteStore.swift`
- 修改：`macos/Tests/MemoriaProtocolChecks/main.swift`

**执行范围**

`value_struct` 只覆盖三类高价值、低歧义字段：

| `profile_category` | `value_struct` 形状 | 说明 |
| --- | --- | --- |
| `anniversaries` | `{ "kind": "birthday|anniversary|exam|work_start|other", "date_label": "原文日期", "month": 5, "day": 20, "year": null }` | 不确定字段用 null |
| `dietary_allergy` | `{ "kind": "dislike|allergy|religious|health|unknown", "item": "香菜", "severity": "low|medium|high|unknown" }` | 避免把过敏和不喜欢混淆 |
| `contact` | `{ "channel": "wechat|phone|email|instagram|linkedin|other", "value": "原文值", "visibility": "private|normal" }` | 不自动公开 |

新增 `GiftSocialRisk` enum：

- `surprise_sensitive`
- `budget_uncertain`
- `preference_uncertain`
- `relationship_sensitive`
- `avoid_topic`
- `timing_sensitive`
- `duplicate_gift_risk`

**规则**

- `value_struct` 不替代 `proposed_value`，只是补充。
- `LocalSQLiteStore.applyProfilePatch` 仍写入人类可读 `proposed_value`。
- 高风险礼物线索默认不可批量批准。
- 生日类输入必须区分三件事：朋友生日日期、提醒触发日期、是否每年重复。`下周三生日` 不能静默写成永久生日；如果无法从原文确认月/日，只能进入“待确认日期”。
- 忌口类输入必须区分“不喜欢”和“过敏”。不能把“不喜欢香菜”写成高严重度过敏。
- 联系方式必须默认按私密信息处理，批准前显示目标人物和渠道。

**验收**

- 生日、忌口、联系方式 fixture 可解析并保留 `value_struct`。
- `proposed_value` 仍能合并进 `category_notes_json`。
- `risk_tags` 非法枚举被拒绝。
- 相对生日日期必须生成待确认状态，不能自动覆盖 `FriendPerson.birthday`。
- `以前喜欢咖啡，最近戒咖啡` 必须进入 `conflicts` 或生成更新建议，不能简单 append 成两个并列偏好。

### Task P1.4：整理台快速纠错闭环

**文件**

- 修改：`macos/Sources/MemoriaMac/Views/InboxView.swift`
- 修改：`macos/Sources/MemoriaMac/Persistence/Repositories/PendingUpdateRepository.swift`
- 修改：`macos/Sources/MemoriaMac/Stores/DashboardStore.swift`

**用户必须能做**

- 改目标人物。
- 从候选人物中确认一个人。
- 改写入位置：自我检索 / 朋友档案管理 / 行程安排。
- 改朋友档案类别。
- 改提醒日期和时间。
- 改生日日期、是否每年重复、日期来源说明。
- 改忌口/过敏类型与严重度。
- 改礼物对象、预算、场合、风险和确认问题。
- 改关系变化内容，并确认当前关系语境。
- 拒绝并保留简短原因。
- 批准后能撤销最近一次批准，恢复旧朋友档案值或删除误建提醒/误建礼物线索，并保留撤销记录。
- 在朋友详情或已确认记忆里发起纠错：标记错误、改给另一个人、替换事实、标记为过期。

**错了怎么发现**

每张会改变既有资料的卡片必须显示：

- 旧值：当前朋友档案、当前提醒或当前礼物线索中已有的值。
- 新建议：AI 准备写入的值。
- 判断依据：为什么识别为这个人、这个类别、这个日期、这个礼物风险。
- 冲突提示：如果新旧矛盾，显示 `可能和旧记录冲突`。
- 覆盖方式：追加、替换、待确认，不允许隐式覆盖。
- 来源原句：默认 1-2 行，展开后显示完整引用。

**分类依据**

整理台不能只说“AI 认为”。每张卡片必须把 `review_explanation` 转成用户能看懂的依据：

| 依据 | 用户可见内容 | 失败时行为 |
| --- | --- | --- |
| 人物匹配 | `为什么是 Alex Chen：命中昵称 Alex，且原文提到 DKU 室友` | 多个候选时必须让用户选人 |
| 分类依据 | `为什么进入朋友档案：这句话描述的是对方稳定偏好` | 分类不确定时不能批量批准 |
| 日期依据 | `为什么日期未定：原文只有“下周三”，需要确认具体日期` | `due_at = null` 并显示未定日期 |
| 礼物风险 | `为什么送礼前要确认：预算和惊喜风险未确定` | 高风险项单独审核 |
| 置信度依据 | `为什么可信/不可信：来源是用户原文，不是模型联想` | 缺依据时按低置信处理 |

**信息时效**

过期信息是一等状态，而不是普通冲突文案。`freshness` 是 envelope 顶层字段，必须支持：

| 字段 | 允许值 | UI 行为 |
| --- | --- | --- |
| `effective_status` | `current` / `stale` / `conflict` / `temporary` / `superseded` | 显示“当前有效 / 可能过期 / 和旧记录冲突 / 暂时状态 / 替代旧记录” |
| `last_observed` | ISO 日期或 null | 显示“最后确认：日期”；没有日期则显示“最后确认时间未知” |
| `staleness_reason` | 文本或 null | 解释“以前喜欢、最近不喜欢、暂时戒”等语义 |
| `supersedes_memory_id` | `MemoryAtom.id` 或 null | 有替代旧记录时显示旧记录入口 |

`以前喜欢咖啡，最近戒咖啡` 必须生成 `effective_status = "conflict"` 或 `superseded` 的更新建议，不能让两个偏好并列成同等当前事实。

**已确认资料纠错**

用户几天后发现错误时，不应依赖“最近撤销”。P1 必须增加从朋友详情和记忆详情进入的纠错动作：

- `标记错误`：把对应 `MemoryAtom.status` 标记为现有的 `disputed`；不静默删除原记忆。
- `改给另一个人`：创建新的候选人物确认 `PendingUpdate`，来源仍指向原 `RawEntry` / `MemoryAtom`。
- `替换事实`：创建 profile patch 待审项，显示旧值、新值、来源和纠错原因。
- `标记过期`：创建 `effective_status = stale/superseded` 的待审项，不强行覆盖手动编辑后的档案。

**敏感遮罩**

联系方式、健康/过敏、关系敏感内容默认按私密处理：

- overview 和列表卡片默认遮罩具体联系方式，只显示渠道，例如 `微信号：已隐藏`。
- 健康、过敏、关系敏感内容在列表只显示摘要，完整内容需要展开卡片。
- 候选列表不得在未展开状态显示完整手机号、邮箱、微信号。
- 锁屏、系统截图或旁人可见的场景不做额外系统集成，但产品内默认列表必须避免明文铺开敏感字段。

**高频审核效率**

高社交需求用户会连续审核。P1/P2 必须同时保留安全边界和效率：

- 编辑保存后提供 `保存修改并批准` 和 `保存修改并继续审核` 两个明确动作。
- 低风险队列支持连续审核；高风险、敏感、同名、未定日期自动退出连续模式。
- 队列默认排序：schema 失败和高风险在顶部，其次是生日/近期提醒，其次是普通朋友事实。
- 支持 `跳过` 当前卡片但不拒绝；跳过后本轮排到队尾。
- 键盘路径覆盖：`Tab` 移动、`Cmd+Return` 批准、`Delete` 拒绝、`Esc` 取消编辑、`Cmd+E` 编辑。

**用户侧撤销**

- 撤销入口只对最近批准且仍可安全回滚的项目显示。
- 撤销不新增 SQLite 表或列；撤销前镜像必须写入现有 `pending_updates.payload_json` 的兼容 envelope，保留 `proposal`，并写入 `approval_result`、`undo.preimage`、`undo.result`。
- 如果当前项目已有 `audit_events` 表，可以把同一份撤销摘要镜像到 `audit_events.detail_json`；但实现不得依赖新增表。
- `approval_result` 必须在批准事务内或同一个用户操作的最小原子边界内写入；写入失败时不得显示可撤销。
- `approval_result` 必须记录 `approved_at`、`memory_atom_id`、`derived_reminder_id`、`derived_gift_idea_id`、`profile_patch_preimage`、`profile_patch_expected_value`；无对应派生对象时用 null。
- `undo.preimage` 必须记录批准前旧值和批准后预期值，`undo.result` 必须记录 `applied` / `blocked` / `not_available` 与原因。
- 撤销朋友档案 patch：只有当当前 category note 仍等于批准后的预期值时，才恢复批准前文本；如果用户后来手动改过，创建一条新的纠错 `PendingUpdate`，不强行覆盖。
- 撤销提醒：只删除由该 `MemoryAtom` 派生、且未被用户后续编辑过的 reminder；保留原始 `RawEntry` 和 source trace。
- 撤销礼物线索：将对应确认 `MemoryAtom.status` 标记为 `archived` 或 `disputed`；不把 approved `PendingUpdate` 改回 pending，不删除用户之后手动创建的 `GiftIdea`。
- approved `PendingUpdate` 保持 approved；撤销结果记录在 payload envelope 或现有审计表中，避免新增 `PendingUpdateStatus`。

`approval_result` 最小字段：

| 字段 | 类型 | 写入时机 |
| --- | --- | --- |
| `approved_at` | ISO 时间字符串 | 批准事务内 |
| `memory_atom_id` | `MemoryAtom.id` | `memory_atoms` 插入成功后 |
| `derived_reminder_id` | reminder id 或 null | `createReminderIfApproved` 后；未生成则 null |
| `derived_gift_idea_id` | gift idea id 或 null | P1 默认必须为 null |
| `profile_patch_preimage` | `{ "person_id": "...", "category": "...", "old_value": "..." }` 或 null | apply profile patch 前 |
| `profile_patch_expected_value` | 字符串或 null | apply profile patch 后预期值 |

`undo` 最小字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `state` | `available` / `applied` / `blocked` / `not_available` | 控制撤销按钮是否出现 |
| `preimage` | object 或 null | 批准前旧值、派生对象 id、memory id |
| `result` | object 或 null | 撤销执行结果和失败原因 |
| `created_correction_pending_update_id` | `PendingUpdate.id` 或 null | 被后续手动编辑阻止时生成的纠错项 |

**批量规则**

只允许批量批准低风险项：

- `confidence >= 0.85`
- `sensitivity == normal`
- `is_ai_inferred == false`
- 目标人物唯一匹配
- 没有 `memory_proposals[].relationship_edge_proposals`
- 没有 `risk_tags`
- 日期不为未知，或不是行程类

不满足任何一条都必须单独确认。

**验收**

- 同名/昵称候选不会自动绑定。
- 高风险礼物线索不能批量批准。
- 关系变化不能批量批准。
- 用户能在卡片上看见改错入口。
- 用户能看到旧值 vs 新建议。
- 用户能看到人物、分类、日期或风险的判断依据。
- 过期/冲突/暂时状态不会和当前事实并列展示。
- 联系方式、健康/过敏、关系敏感内容在列表默认遮罩。
- 批准后撤销不会删除 `RawEntry`。
- 撤销朋友档案 patch 能恢复旧 category note。
- 撤销被后续手动编辑阻止时，会生成纠错待审项而不是强行覆盖。
- 批准事务完成后，approved update 的 `payload_json` 必须仍是合法 envelope，并持久化 `approval_result.memory_atom_id`、`.reminderSource` 的 `derived_reminder_id` 或 null、以及正确的 `undo.state`。
- 几天后发现错误时，可从朋友详情发起纠错，不依赖最近撤销入口。
- 连续审核遇到高风险、敏感、同名或未定日期会停下。
- 相对生日日期卡片默认单独确认，不能批量批准。

## 6. P2：整理台 UI contract 与视觉/可访问性

P2 的目标是把 schema 改动转译成 Quiet Premium、macOS-native 的整理台体验。

### Task P2.1：整理台层级

**文件**

- 修改：`macos/Sources/MemoriaMac/Views/InboxView.swift`
- 修改：`macos/Sources/MemoriaMac/Views/CaptureMemoryActionsViews.swift`
- 修改：`macos/Sources/MemoriaMac/Models/DashboardModels.swift`

**信息架构**

- 侧边栏点 `整理台`：打开 overview，`selectedReviewCategory == nil`。
- 记录提交后：打开对应分区。
- overview 展示三组队列：
  - 自我检索
  - 朋友档案管理
  - 行程安排
- 分区页只展示该分区待审项。
- 失败项始终在队列顶部，但不能抢走已输入原文。

**卡片字段顺序**

1. 目标对象或模式：例如 `Alex Chen` / `行程安排` / `自我检索`
2. 建议摘要：一句话
3. 旧值 vs 新建议：仅在会更新既有资料时显示
4. 判断依据：为什么识别为此人、此类别、此日期或此风险
5. 信息时效：当前有效、可能过期、冲突、暂时状态或替代旧记录
6. 来源原文：折叠显示，默认 1-2 行
7. 状态标签：`需要确认`、`AI 推断`、`敏感内容`、`未定日期`、`高风险礼物`
8. 将写入哪里：朋友档案 / 自我检索 / 行程安排
9. 主要操作：编辑、批准、拒绝

**按钮与快捷键 contract**

- 最终视觉顺序固定为：`编辑`、`批准`、`拒绝`。现有 `编辑`、`丢弃`、`批准` 顺序必须在 P2 调整。
- `批准` 使用 primary/prominent 样式，是默认正向动作，快捷键 `Cmd+Return`。
- `拒绝` 使用 destructive role，文字统一为 `拒绝`，快捷键 `Delete`；不得在中文 UI 用 `丢弃` 作为主文案。
- `编辑` 快捷键 `Cmd+E`；编辑态内 `Esc` 取消编辑。
- VoiceOver 顺序必须和视觉顺序一致：卡片摘要 -> 来源 Disclosure -> 编辑 -> 批准 -> 拒绝。
- 批准或拒绝后焦点移动到下一张待审卡片；没有下一张时回到空状态标题。

**按类型必显字段**

| 卡片类型 | 必显字段 | 可折叠字段 | 禁止行为 |
| --- | --- | --- | --- |
| 朋友事实 | 目标人物、档案类别、旧值、新建议、来源原文、写入位置 | 置信度、候选人物详情、完整原文 | 不显示“旧值 vs 新建议”就允许批准 |
| 行程提醒 | 标题、目标人物、提醒日期、日期来源、未定日期状态、来源原文 | 时间解析细节、原始 due label | 把相对生日静默写成永久生日 |
| 礼物线索 | 目标人物、场合、预算、风险标签、确认问题、来源原文 | 完整风险解释、候选礼物方向 | 高风险项一键批量批准或自动生成最终礼物 |
| 关系变化 | 涉及人物、关系变化摘要、敏感状态、来源原文、确认问题 | 关系边 tags、confidence | 自动改变 `manual_closeness_level` |
| schema 失败 | 错误摘要、原文已保存、下一步操作 | 技术错误详情 | 只显示错误码不告诉用户下一步 |
| 同名候选 | 原文姓名、候选列表、需要确认谁 | 每个候选的上下文 | 自动绑定第一个候选 |

### Task P2.2：用户可见 microcopy

禁止在主 UI 直接显示 schema jargon。使用以下文案：

| 技术字段 | 用户可见文案 |
| --- | --- |
| `source_quote` | 来自这句话 |
| `review_explanation.target_match_reason` | 为什么是这个人 |
| `review_explanation.category_reason` | 为什么归到这里 |
| `review_explanation.date_parse_reason` | 为什么日期这样处理 |
| `freshness.effective_status: stale` | 这条可能已经过期 |
| `freshness.effective_status: conflict` | 这条和旧记录冲突 |
| `freshness.effective_status: temporary` | 这可能只是暂时状态 |
| `is_ai_inferred` | AI 推断，确认前不会保存成事实 |
| `sensitivity: private` | 私密内容 |
| `sensitivity: sensitive` | 敏感内容 |
| 敏感字段遮罩 | 已隐藏，展开后查看 |
| `profile_category` | 将写入：朋友档案的「饮食偏好/忌口过敏/...」 |
| `schema validation failure` | AI 输出结构不完整，原文已保存 |
| `target_person_id == nil` | 需要确认是谁 |
| `due_at == null` | 未定日期 |
| `risk_tags` | 送礼前需要确认 |
| `candidate_person_ids` | 找到多个可能的人，请选一个 |
| 批量批准不可用 | 有高风险或不确定信息，需要单独确认 |
| 拒绝原因 placeholder | 为什么不保存这条？可选填写 |
| schema 失败下一步 | 原文已保存。你可以重新生成，或手动整理 |
| 编辑保存 | 保存修改并继续审核 |
| 编辑取消 | 放弃修改 |
| 高风险礼物 | 先确认这些问题，避免送错或破坏惊喜 |
| 新旧冲突 | 这条建议可能和旧记录冲突 |
| 批准后撤销 | 撤销刚才的保存 |
| 撤销成功 | 已撤销，原文仍保留 |
| 撤销不可用 | 这条之后被手动改过，已为你生成纠错待审项 |
| 跳过 | 稍后再看 |
| 保存修改并批准 | 保存修改并批准 |
| 保存修改并继续审核 | 保存修改并继续审核 |

### Task P2.3：Quiet Premium 视觉规则

- 使用克制色彩，状态标签低噪声，不把每个 schema 字段做成 badge。
- 风险、敏感、失败状态的视觉优先级高于普通置信度。
- 长原文折叠，用户点击后展开。
- 卡片不做 CRM 式密集表格，不堆满指标。
- macOS 侧边栏保持原生 source-list rhythm；详细内容放右侧 detail 区。
- 正常窗口下，列表和详情可以并排；窄窗口下，详情区进入同列下方或独立编辑 sheet。
- 联系方式、健康/过敏、关系敏感字段在列表默认遮罩，展开后仍保持来源和写入位置清晰。
- 连续审核模式保持安静，不做游戏化进度条；只显示当前剩余数量和下一个高风险停顿点。

**窄窗口规则**

- 设计最小可用宽度按 640pt 验收；低于该宽度不要求完整双栏。
- 禁止横向滚动主内容；长文本必须换行或折叠。
- 来源原文默认最多 2 行；展开后最多占卡片高度的 40%，再用内部滚动。
- 主要操作顺序保持：编辑、批准、拒绝；宽度不足时按钮纵向堆叠，按钮文字不截断。
- 状态标签最多显示 2 个高优先级标签，其余进入“更多状态”折叠区。
- 旧值 vs 新建议在窄窗口下纵向排列，不能压缩成两列小字。
- 编辑表单字段单列排列，每个字段都有 label，保存/取消固定在表单底部。

### Task P2.4：可访问性验收

必须满足：

- 状态不只靠颜色表达，要有图标或文字。
- 键盘可完成选择卡片、编辑、批准、拒绝。
- VoiceOver 能读出：目标对象、建议摘要、是否推断、是否敏感、将写入哪里、来源原文。
- 焦点顺序和视觉顺序一致：卡片 -> 来源 -> 编辑 -> 批准 -> 拒绝。
- 长中文文本不溢出按钮或卡片边界。
- 文本和背景对比度至少满足 WCAG AA。
- 当前焦点必须有可见 focus ring 或等效 macOS 原生焦点样式。
- 批准、拒绝、撤销后焦点回到下一张待审卡片；如果列表为空，焦点回到空状态标题。
- schema 失败和撤销成功需要有可被 VoiceOver 读出的状态更新。
- 来源原文 Disclosure 必须有明确展开/收起语义。
- 编辑表单每个输入有 label，必要时有 hint，例如“如果不确定生日年份，年份留空”。

**SwiftUI accessibility 模板**

每类 `PendingUpdateCard` 必须提供可读标签和操作命名。不要把包含按钮、Disclosure、候选列表的整张卡片 `.combine`，否则交互控件可能被 VoiceOver 合并掉。

```swift
VStack(alignment: .leading, spacing: 12) {
    summaryHeader
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(targetName)，\(proposalSummary)，\(statusText)，将写入 \(destinationText)")
        .accessibilityHint("继续浏览可查看来源原文、判断依据和操作按钮")

    sourceDisclosure
    actionBar
}
.accessibilityElement(children: .contain)
.accessibilityIdentifier("pending-update-card-\(update.id)")
```

按钮命名：

- 编辑：`accessibilityLabel("编辑这条建议")`
- 批准：`accessibilityLabel("批准并保存这条建议")`
- 拒绝：`accessibilityLabel("拒绝这条建议")`
- 撤销：`accessibilityLabel("撤销刚才的保存")`
- 跳过：`accessibilityLabel("稍后再看这条建议")`

建议 identifiers：

- 卡片：`pending-update-card-{id}`
- 来源 Disclosure：`pending-update-source-{id}`
- 判断依据：`pending-update-explanation-{id}`
- 编辑：`pending-update-edit-{id}`
- 批准：`pending-update-approve-{id}`
- 拒绝：`pending-update-reject-{id}`
- 撤销：`pending-update-undo-{id}`

Disclosure 命名：

- 折叠状态：`accessibilityLabel("展开来源原文")`
- 展开状态：`accessibilityLabel("收起来源原文")`

状态播报：

- schema 失败：播报 `AI 输出结构不完整，原文已保存`
- 撤销成功：播报 `已撤销，原文仍保留`
- 候选人物：播报 `找到多个可能的人，请先选择`

焦点回归：

- 使用 `@AccessibilityFocusState` 或等效 macOS focus 管理记录当前卡片 id。
- 批准、拒绝、跳过、撤销后，把焦点移动到下一张可审核卡片。
- 如果撤销被阻止，焦点移动到生成的纠错待审项或阻止原因提示。
- 如果列表为空，焦点移动到空状态标题 `整理台已清空`。

### Task P2.5：视觉 QA 场景

至少覆盖：

- overview 无待审项。
- overview 有三类待审项。
- 朋友事实：`Alex 喜欢火锅，不吃香菜`。
- 行程提醒：`下周三提醒我问 Jason 内推材料`。
- 礼物线索：`May 想试拍立得相纸和小型香水`。
- schema 失败：AI 输出缺 `source_quote`。
- 同名朋友：`Alex` 匹配多个候选。
- 未定日期提醒。
- 敏感自我反思。

窗口尺寸必须固定覆盖：

- 1280x840：正常双栏。
- 900x720：紧凑双栏。
- 640x720：最小可用宽度，主内容无横向滚动。
- 520x720：允许降级为单列或 sheet，但按钮和文本不能溢出。

**fixture 注入**

- 新增 `macos/Tests/Fixtures/review_ui_pending_updates.json`，覆盖上面的所有视觉 QA 场景。
- 增加 debug-only loader 或测试 helper，把 fixture 写入本地测试 SQLite；不得进入生产启动路径。
- 每条 fixture 必须含稳定 `PendingUpdate.id`，用于 accessibility identifier 和截图命名。
- UI 测试或手动 QA 不依赖真实 DeepSeek 调用。

**截图和检查路径**

- 截图输出到 `macos/TestArtifacts/ReviewUI/`，文件名包含场景和窗口宽度，例如 `friend-fact-640.png`。
- 每次视觉验收至少保存 overview、朋友事实、提醒、礼物线索、同名候选、schema 失败六类截图。
- 截图检查重点：无横向滚动、按钮不截断、敏感字段默认遮罩、旧值/新建议可比较、状态标签不超过 2 个。

**UI 自动化建议**

- 若项目引入 XCUITest，新增 `ReviewInboxUITests`，只使用 fixture loader，不访问网络。
- 如果暂不引入 XCUITest，必须保留手动脚本：启动测试数据、按四个窗口尺寸检查、开启 VoiceOver 逐项 Tab、记录截图路径。
- `MemoriaProtocolChecks` 继续覆盖协议；UI/a11y 通过 `ReviewInboxUITests` 或手动验收表覆盖，不能用 `swift build` 代替视觉验收。

**pass/fail 检查表**

| 检查项 | Pass 标准 |
| --- | --- |
| 来源原文默认高度 | 默认 1-2 行，展开前不淹没卡片 |
| 状态标签 | 高优先级标签不超过 2 个，且都有文字 |
| 主操作 | 按钮文字完整，窄窗口下纵向堆叠也不溢出 |
| 旧值 vs 新建议 | 可读、可比较，不用小号密集表格 |
| 判断依据 | 每张卡片能看见人物/分类/日期/风险中相关依据 |
| 敏感遮罩 | overview 和列表默认不明文铺开联系方式、健康、关系敏感内容 |
| schema 失败 | 显示“原文已保存”和下一步操作 |
| 同名候选 | 明确要求用户选择，不自动绑定 |
| 长中文 | 不越界，不遮挡按钮 |
| 键盘 | Tab 顺序符合卡片 -> 来源 -> 编辑 -> 批准 -> 拒绝 |
| VoiceOver | 读得出推断/敏感/写入位置/来源 |
| 窄窗口 | 无横向滚动，详情区不挤压列表 |
| 焦点回归 | 批准/拒绝/跳过/撤销后焦点进入下一张卡片或空状态 |

**逐类型可访问性断言**

| 卡片类型 | VoiceOver 必须读出 | 键盘路径 |
| --- | --- | --- |
| 朋友事实 | 目标人物、档案类别、旧值、新建议、来源、将写入朋友档案 | 卡片 -> 来源 -> 编辑类别/人物 -> 批准 -> 拒绝 |
| 行程提醒 | 标题、提醒日期、日期来源、未定日期状态、来源、将写入行程安排 | 卡片 -> 来源 -> 编辑日期 -> 批准 -> 拒绝 |
| 礼物线索 | 目标人物、场合、预算、风险、确认问题、来源 | 卡片 -> 来源 -> 编辑风险/问题 -> 批准 -> 拒绝 |
| 关系变化 | 涉及人物、敏感状态、确认问题、来源、不改变亲近等级 | 卡片 -> 来源 -> 编辑关系描述 -> 批准 -> 拒绝 |
| schema 失败 | 错误摘要、原文已保存、重新生成或手动整理 | 卡片 -> 技术详情 -> 重新生成 -> 手动整理 |
| 同名候选 | 原文姓名、候选人数、需要选择谁 | 卡片 -> 候选列表 -> 确认人物 -> 编辑 -> 批准 |

**手动 VoiceOver 脚本**

1. 用 fixture loader 打开整理台 overview。
2. 设为 640x720 窗口。
3. 从第一张卡片开始按 `Tab`，确认顺序为卡片摘要、来源、编辑、批准、拒绝。
4. 展开来源，确认 VoiceOver 读出“来自这句话”和完整来源。
5. 进入同名候选卡，确认候选列表可逐项选择，未选前批准不可用或会提示需要确认。
6. 批准一条低风险卡，确认焦点进入下一张卡。
7. 撤销刚批准项，确认读出“已撤销，原文仍保留”。
8. 对被后续手动修改的项目尝试撤销，确认显示阻止原因并生成纠错待审项。

## 7. 真实社交 QA 用例

新增测试和手动 QA 必须覆盖以下高风险场景：

| 场景 | 输入 | 期望 |
| --- | --- | --- |
| 朋友事实不是自我反思 | `Alex Chen 喜欢吃薯片。` | 进入朋友档案，不生成“我害怕麻烦别人” |
| 忌口 vs 过敏 | `May 不喜欢香菜，但不是过敏。` | `dietary_allergy.value_struct.kind = dislike` |
| 生日相对日期 | `Jason 下周三生日，提醒我提前买蛋糕。` | 日期不确定时 `due_at = null` 或由本地可解释规则生成 |
| 同名朋友 | `Alex 说他换工作了。` | 出现候选人物，不能自动绑定 |
| 礼物惊喜风险 | `不要让 May 知道我在准备礼物。` | `risk_tags` 包含 `surprise_sensitive` |
| 关系敏感 | `我和他最近有点尴尬，不确定还适不适合送。` | `relationship_sensitive`，不可批量批准 |
| 多人一句话 | `May 说 Alex 最近压力很大。` | 正确区分说话者和被描述者 |
| 过期偏好 | `Alex 以前喜欢咖啡，但最近说戒咖啡。` | 产生冲突或更新建议，不直接覆盖旧事实 |
| 文件/截图导入 | 文件备注来自导入内容 | 保留 source quote 和文件来源 |
| 批准后发现错误 | 批准 `Alex 不吃香菜` 后发现是另一个 Alex | 可撤销批准，恢复旧档案值，并回到候选人物确认 |
| 几天后发现错误 | 已确认 `Alex 不吃香菜`，三天后发现是 Jason | 从朋友详情发起“改给另一个人”纠错，不依赖最近撤销 |
| 朋友改口 | `May 以前不喝咖啡，现在说可以喝拿铁` | 显示旧值、新建议、最后确认时间和替代旧记录 |
| 联系方式 | `Jason 微信是 abc123` | 列表默认显示“微信号：已隐藏”，展开后才能看完整值 |
| 连续审核停顿 | 连续批准低风险项后遇到同名 Alex | 自动退出连续审核，要求选人 |
| 礼物防尴尬 | `预算别太高，不然她会有压力` | `budget_uncertain` 或 `avoid_topic`，确认问题可编辑 |
| 重复礼物 | `去年已经送过香水，今年别再送一样的` | `duplicate_gift_risk`，不进入自动推荐 |
| 生日 vs 提醒日期 | `下周三提醒我给 Jason 过生日` | 区分“提醒日期=下周三”和“生日日期待确认/或已知生日” |

## 8. 回滚策略

P0/P1/P2 都必须可回滚：

- P0 回滚：移除严格 key validator 或关闭调用点；v1.0 解码保持不变。
- P1 回滚：撤掉 prompt 中 v1.1 输出要求；Swift 继续能读 v1.0；不删除 legacy 字段；不迁移 DB。
- P2 回滚：恢复旧整理台卡片布局；sidebar IA、overview、三分区入口不变。

任何回滚都不得删除：

- `RawEntry`
- 已存在 `PendingUpdate`
- 已批准 `MemoryAtom`
- 用户手动编辑过的朋友档案
- DeepSeek Keychain 数据

用户侧撤销不是工程回滚。撤销只针对单条批准结果，必须保留原始 `RawEntry`、source trace、approved `PendingUpdate` 和用户之后的其他手动编辑；撤销记录写入现有 `pending_updates.payload_json` 兼容 envelope，最少包含 `approval_result.memory_atom_id`、派生对象 id、`undo.preimage` 和 `undo.result`。已有 `audit_events` 时可镜像但不依赖新增 schema。

## 9. 验证命令

每个阶段完成后运行：

```bash
cd macos
swift run MemoriaProtocolChecks
swift build

cd ..
bash ./script/build_and_run.sh --verify
```

如果直接 app verify 在本机 dyld 阶段挂起，以 `swift run MemoriaProtocolChecks` 和 `swift build` 作为代码级 gate。

文档和 schema 检查：

```bash
node - <<'NODE'
const fs = require('fs');
for (const path of [
  'docs/schemas/extract-memory.generation.v1.1.schema.json',
  'docs/schemas/extract-memory.canonical.v1.1.schema.json'
]) {
  JSON.parse(fs.readFileSync(path, 'utf8'));
  console.log(`ok ${path}`);
}
NODE
git diff --check
```

UI/a11y 验收不是 `swift build` 的替代项。P2 完成时还必须执行其一：

- 自动：`ReviewInboxUITests` 使用 fixture loader 跑四个窗口尺寸，并输出截图到 `macos/TestArtifacts/ReviewUI/`。
- 手动：按 Task P2.5 的 VoiceOver 脚本逐项检查，并把截图路径记录到 PR 或验收记录。

## 10. 最终验收门槛

这份优化真正完成时必须同时满足：

- 工程：所有新增协议测试通过，v1.0/v1.1 兼容，未知版本 fail closed。
- 工程：legacy direct payload 和 v1.1 envelope payload 都能显示、编辑、批准、撤销。
- 安全：AI 不直接写最终事实，不泄露 API key，不自动联网。
- 实用：用户能改人、改类、改日期、改风险、拒绝和纠错。
- 实用：用户能撤销误批准，也能从已确认资料发起“标记错误 / 改给另一个人 / 替换事实 / 标记过期”。
- 实用：用户能看到旧值 vs 新建议、分类依据、信息时效、同名朋友和日期不确定。
- 视觉：整理台能一眼看出来源、判断依据、推断、敏感、写入位置、旧新冲突和下一步。
- 可访问性：卡片容器不吞掉交互控件，VoiceOver 和键盘顺序与视觉顺序一致。
- 回滚：关闭 v1.1 prompt 后旧链路继续工作。

## 11. 修订后自评分

| 维度 | 分数 | 理由 |
| --- | ---: | --- |
| 工程可执行性 | 96 | 已明确文件、阶段、校验范围、mapping、回滚触发点 |
| 安全性 | 97 | 明确不改 provider、不改 DB、不跳过整理台、不自动联网 |
| 实用性 | 97 | 增加撤销、旧值 vs 新建议、同名候选、批量规则、生日忌口联系方式最小结构化 |
| 美观性 | 96 | 增加按类型卡片 contract、microcopy、Quiet Premium、窄窗口规则和 pass/fail QA |
| 可访问性 | 96 | 增加对比度、焦点回归、状态播报、Disclosure 语义和编辑表单 label/hint |

综合自评分：96.5。
