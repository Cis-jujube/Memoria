# Memoria macOS-first 重构执行规格

> 用法：把本文件整体复制给 Codex，或放到项目根目录作为 `docs/MEMORIA_MACOS_CODEX_MASTER_SPEC.md`，然后让 Codex 按阶段执行。

---

## 0. Codex 角色设定

你是这个现有 Memoria 仓库的主工程 Agent。你的任务不是重写一个新项目，而是在现有代码基础上，把 Memoria 从“朋友关系管理工具”重构成一个 **macOS-first、local-first、AI-assisted 的个人记忆宫殿与关系图谱系统**。

你必须先审计当前仓库，再增量修改。不要盲目删除现有功能。不要为了视觉炫技牺牲可用性。不要把 AI 输出直接写入最终档案。所有 AI 结构化结果必须先进入待确认机制。

---

## 1. 项目当前背景

Memoria 当前已经有：

- Web reference app：Next.js、Prisma/Postgres、AI Inbox、people、groups、reminders、gifts、search、relationship graph、file import、tests。
- native/local-first 方向：macOS、iOS、Android、Windows 已经有不同程度的本地端实现。
- macOS：SwiftUI + SQLite + Keychain，已有可运行的 MemoriaMac。
- iOS：SwiftUI 包和应用源文件，目标 iOS 17+。
- Android：Java native views + SQLiteOpenHelper + Android Keystore encrypted preferences。
- Windows：Tauri + React/TypeScript + Rust + rusqlite + OS keyring。
- 共同边界：关系数据保存在本地 SQLite；用户自己的 DeepSeek API key 保存在系统安全存储；AI 识别结果进入 AI Inbox / PendingUpdate，确认后才修改资料。

本轮开发决定：

```text
Primary runtime: macOS
Reference only: Web
Paused compatibility targets: iOS / Android / Windows
Core goal: build Personal Memory Core on macOS first
```

---

## 2. 一句话产品定义

Memoria 是一个 **AI 个人记忆宫殿 + 关系图谱系统**。

它让用户随手输入或口述一段想法、感悟、聊天记录、朋友信息、提醒、礼物线索或文件笔记，然后由 AI 分类、摘要、提炼、关联人物和主题，生成待确认记忆。用户确认后，这些记忆进入一个可搜索、可回看、可继续讨论、可产生提醒和关系洞察的长期记忆系统。

不要把它做成普通通讯录。不要把它做成职业 CRM。不要把它做成单纯日记。它的核心是：

```text
Free-form input
→ AI organizes
→ User confirms
→ Memory atoms are saved
→ People, themes, reminders, gifts and relationship graph are derived from memory
```

---

## 3. 开发理念：Memory Protocol，而不是 Big Agent

### 3.1 不要做一个不可控的大 Agent

不要实现：

```text
用户输入
→ 一个大 Agent 自己判断一切
→ 自己改数据库
→ 自己更新朋友档案
→ 自己创建提醒
```

这会造成误写入、幻觉记忆、隐私风险、后期难维护。

### 3.2 实现 workflow-first、agent-second

稳定、带副作用的流程必须是 workflow：

```text
输入分类
结构化抽取
生成待确认变更
用户确认
写入最终数据
```

开放式能力可以是 agent-like：

```text
Ask with Memory
继续讨论某条记忆
礼物推荐
周期复盘
关系变化总结
```

### 3.3 DeFi / protocol 思维类比

用协议化方式理解 Memoria：

```text
资产 Asset: MemoryAtom
账本 Ledger: RawEntry + AuditEvent
交易 Transaction: PendingUpdate
预言机 Oracle: DeepSeek / LLM
签名 Signature: User Approval
协议 Protocol: Extraction / Review / Linking / Retrieval / Reflection
组合模块 Composables: Gift Agent / Reminder Agent / Relationship Agent / Reflection Agent
风控 Risk Control: source traceability + confidence + sensitivity + human approval
```

AI 不是事实来源。AI 只是“记忆预言机”。

真正可信的是：

```text
原始输入 RawEntry
用户确认 User Approval
来源引用 SourceQuote
可追溯 ID
```

---

## 4. 不变量：任何实现都不能破坏

1. 每条最终记忆必须有 `source_entry_id` 或 `source_quote`。
2. AI 不能直接创建、覆盖、删除 confirmed 数据。
3. AI 输出必须先变成 `PendingUpdate`。
4. 用户必须可以 approve / edit / reject 每条 AI 建议。
5. 敏感记忆默认隐藏或弱化展示。
6. 低置信度事实必须要求确认。
7. 关系等级变化必须显式确认。
8. 礼物推荐必须引用依据，不能凭空编造。
9. 朋友档案里的结论必须能回到来源记忆。
10. DeepSeek API key 不能写入 SQLite、日志、测试 fixture、源码或导出文件。
11. macOS 是本轮唯一主线目标。不要为了 iOS/Android/Windows 牺牲 macOS 交付。
12. Web 是 visual/reference app，不是本轮 primary runtime。

---

## 5. 本轮核心目标

把 macOS 端升级为 Memoria V1.5：Personal Memory Core。

必须跑通这条链路：

```text
我随便输入一段话
→ AI 判断它是什么
→ AI 提炼成一组待确认记忆
→ 我确认
→ 它进入 Memory Palace
→ 它能关联人物和主题
→ 我能搜索、回看、继续讨论
→ 如果和朋友有关，朋友档案自动显示这条记忆
```

---

## 6. 本轮非目标

暂缓以下内容：

- 复杂 3D 关系星图优化。
- 跨设备同步。
- 云账号系统。
- App Store / TestFlight / notarization 发布流程。
- PDF 深度解析和 OCR。
- 社交平台导入。
- 通讯录自动同步。
- Android / Windows 新功能扩展。
- 过度复杂的关系健康评分。
- 过度礼物推荐商业化。
- 花哨动画和不必要的视觉特效。

---

## 7. macOS 信息架构

主导航必须统一为：

```text
Capture        记录
AI Review      整理台
Memory         记忆宫殿
People         朋友与关系
Actions        行动中心
Ask            对话检索
Settings       设置
```

macOS 推荐使用三栏结构：

```text
Sidebar: main sections
Content list: current section items
Detail panel: selected item detail
```

不要使用太多弹窗。macOS 端应优先使用 sidebar、split view、inspector panel、sheet、popover。

---

## 8. 视觉与体验方向

### 8.1 风格关键词

```text
private
calm
quiet premium
personal archive
memory palace
warm neutral
source-backed
low cognitive load
```

### 8.2 避免

```text
generic SaaS dashboard
corporate CRM look
neon gradients
glassmorphism everywhere
excessive charts
random icons
crowded tables
over-animation
```

### 8.3 推荐视觉原则

- 背景使用温和、低饱和中性色。
- 主内容用 card 和 source quote block 表达“记忆档案”感。
- 敏感信息用私密标签和折叠遮罩，而不是吓人的警告样式。
- AI 状态使用统一语言：`整理中`、`待确认`、`已归档`、`发现冲突`、`可继续讨论`。
- 每条 AI 建议必须显示“为什么 AI 这么提取”，用原文引用而不是推理长文。

### 8.4 设计 token 建议

创建或更新：

```text
docs/DESIGN_SYSTEM.md
design-tokens.json
```

建议 token：

```json
{
  "colors": {
    "background": "#F8F5EF",
    "surface": "#FFFFFF",
    "surfaceMuted": "#F1ECE3",
    "textPrimary": "#241F1A",
    "textSecondary": "#6B6258",
    "accent": "#8B6F47",
    "accentMuted": "#E8DDCC",
    "private": "#7C5C8A",
    "sensitive": "#9B3A3A",
    "aiPending": "#B8792F",
    "confirmed": "#3F7A54",
    "border": "#DED5C8"
  },
  "radius": {
    "sm": 8,
    "md": 14,
    "lg": 22
  },
  "spacing": {
    "xs": 4,
    "sm": 8,
    "md": 16,
    "lg": 24,
    "xl": 32
  },
  "typography": {
    "display": 28,
    "title": 22,
    "section": 17,
    "body": 14,
    "caption": 12
  }
}
```

---

## 9. 核心数据模型：Memory Protocol

### 9.1 四层模型

```text
RawEntry       原始输入
MemoryAtom     最小确认记忆单元
PendingUpdate  AI 待确认变更
DerivedView    People / reminders / gifts / graph / actions
```

### 9.2 RawEntry

保存用户原始输入，不做结构化解释。

字段：

```text
id TEXT PRIMARY KEY
input_type TEXT CHECK IN text | voice_transcript | file | manual | imported_clip
raw_text TEXT NOT NULL
source_file_id TEXT NULL
created_at TEXT NOT NULL
updated_at TEXT NOT NULL
```

### 9.3 MemoryAtom

最终确认后的原子记忆。它是产品核心资产。

类型：

```text
personal_reflection    个人感悟
idea                   灵感
relationship_memory    人际记忆
person_fact            朋友事实
event                  事件
reminder_source        提醒来源
gift_signal            礼物线索
file_note              文件笔记
```

字段：

```text
id TEXT PRIMARY KEY
source_entry_id TEXT NULL
type TEXT NOT NULL
title TEXT NOT NULL
summary TEXT NOT NULL
content TEXT NOT NULL
source_quote TEXT NULL
confidence REAL NOT NULL DEFAULT 1.0
sensitivity TEXT NOT NULL DEFAULT 'normal'
is_ai_inferred INTEGER NOT NULL DEFAULT 0
status TEXT NOT NULL DEFAULT 'confirmed'
event_time TEXT NULL
valid_until TEXT NULL
created_at TEXT NOT NULL
updated_at TEXT NOT NULL
```

### 9.4 PendingUpdate

所有 AI 建议先进入这里。

字段：

```text
id TEXT PRIMARY KEY
source_entry_id TEXT NULL
proposal_type TEXT NOT NULL
payload_json TEXT NOT NULL
confidence REAL NOT NULL DEFAULT 0.0
status TEXT NOT NULL DEFAULT 'pending'
created_at TEXT NOT NULL
decided_at TEXT NULL
error_message TEXT NULL
```

状态：

```text
pending
approved
edited
rejected
failed
```

### 9.5 Theme

用于个人感悟和长期模式归档。

字段：

```text
id TEXT PRIMARY KEY
name TEXT NOT NULL UNIQUE
description TEXT NULL
created_at TEXT NOT NULL
updated_at TEXT NOT NULL
```

示例主题：

```text
自我表达
关系边界
害怕麻烦别人
求职压力
朋友支持
旅行
生日礼物
饮食忌口
长期目标
```

### 9.6 Link tables

```text
memory_person_links
- memory_id TEXT NOT NULL
- person_id TEXT NOT NULL
- relation_type TEXT CHECK IN about | mentioned | involves | inferred
- created_at TEXT NOT NULL

memory_theme_links
- memory_id TEXT NOT NULL
- theme_id TEXT NOT NULL
- created_at TEXT NOT NULL
```

### 9.7 Derived entities

继续保留并接入 MemoryAtom：

```text
people
contact_groups
person_groups
reminders
gift_ideas
relationship_edges
files
ai_runs
audit_events
```

---

## 10. 建议 SQLite schema v2

请根据现有 schema 增量迁移，不要无脑 drop 表。若现有表字段不同，写 migration adapter。

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY,
  applied_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS raw_entries (
  id TEXT PRIMARY KEY,
  input_type TEXT NOT NULL CHECK (input_type IN ('text','voice_transcript','file','manual','imported_clip')),
  raw_text TEXT NOT NULL,
  source_file_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS memory_atoms (
  id TEXT PRIMARY KEY,
  source_entry_id TEXT,
  type TEXT NOT NULL CHECK (type IN ('personal_reflection','idea','relationship_memory','person_fact','event','reminder_source','gift_signal','file_note')),
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  content TEXT NOT NULL,
  source_quote TEXT,
  confidence REAL NOT NULL DEFAULT 1.0,
  sensitivity TEXT NOT NULL DEFAULT 'normal' CHECK (sensitivity IN ('normal','private','sensitive')),
  is_ai_inferred INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed','archived','disputed')),
  event_time TEXT,
  valid_until TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (source_entry_id) REFERENCES raw_entries(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS pending_updates (
  id TEXT PRIMARY KEY,
  source_entry_id TEXT,
  proposal_type TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  confidence REAL NOT NULL DEFAULT 0.0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','edited','rejected','failed')),
  created_at TEXT NOT NULL,
  decided_at TEXT,
  error_message TEXT,
  FOREIGN KEY (source_entry_id) REFERENCES raw_entries(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS themes (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS memory_person_links (
  memory_id TEXT NOT NULL,
  person_id TEXT NOT NULL,
  relation_type TEXT NOT NULL CHECK (relation_type IN ('about','mentioned','involves','inferred')),
  created_at TEXT NOT NULL,
  PRIMARY KEY (memory_id, person_id, relation_type),
  FOREIGN KEY (memory_id) REFERENCES memory_atoms(id) ON DELETE CASCADE,
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS memory_theme_links (
  memory_id TEXT NOT NULL,
  theme_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (memory_id, theme_id),
  FOREIGN KEY (memory_id) REFERENCES memory_atoms(id) ON DELETE CASCADE,
  FOREIGN KEY (theme_id) REFERENCES themes(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS ai_runs (
  id TEXT PRIMARY KEY,
  workflow_name TEXT NOT NULL,
  model TEXT NOT NULL,
  input_summary TEXT,
  output_json TEXT,
  status TEXT NOT NULL CHECK (status IN ('started','succeeded','failed')),
  error_message TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_raw_entries_created_at ON raw_entries(created_at);
CREATE INDEX IF NOT EXISTS idx_memory_atoms_type ON memory_atoms(type);
CREATE INDEX IF NOT EXISTS idx_memory_atoms_created_at ON memory_atoms(created_at);
CREATE INDEX IF NOT EXISTS idx_memory_atoms_sensitivity ON memory_atoms(sensitivity);
CREATE INDEX IF NOT EXISTS idx_pending_updates_status ON pending_updates(status);
CREATE INDEX IF NOT EXISTS idx_pending_updates_created_at ON pending_updates(created_at);
CREATE INDEX IF NOT EXISTS idx_memory_person_links_person ON memory_person_links(person_id);
CREATE INDEX IF NOT EXISTS idx_memory_theme_links_theme ON memory_theme_links(theme_id);
```

如果当前 macOS SQLite 支持 FTS5，添加：

```sql
CREATE VIRTUAL TABLE IF NOT EXISTS memory_atoms_fts USING fts5(
  title,
  summary,
  content,
  source_quote,
  content='memory_atoms',
  content_rowid='rowid'
);
```

如果 FTS5 不可用，先用普通 `LIKE` 搜索作为 fallback。

---

## 11. Swift 代码结构建议

先审计现有 `macos/` 目录，然后尽量贴合当前结构。若当前结构缺失，按下面组织：

```text
macos/
  Sources/
    MemoriaMac/
      App/
        MemoriaMacApp.swift
        AppNavigation.swift
      Domain/
        RawEntry.swift
        MemoryAtom.swift
        PendingUpdate.swift
        Theme.swift
        Person.swift
        Reminder.swift
        GiftIdea.swift
        RelationshipEdge.swift
        AIModels.swift
      Persistence/
        Database.swift
        MigrationManager.swift
        SQLBuilder.swift
        Repositories/
          RawEntryRepository.swift
          MemoryRepository.swift
          PendingUpdateRepository.swift
          ThemeRepository.swift
          PersonRepository.swift
          ReminderRepository.swift
          GiftRepository.swift
          AIRunRepository.swift
      AI/
        DeepSeekClient.swift
        AIWorkflowService.swift
        PromptBuilder.swift
        AIJSONParser.swift
        AIContractValidator.swift
      Security/
        KeychainService.swift
      Features/
        Capture/
          CaptureView.swift
          CaptureViewModel.swift
        AIReview/
          AIReviewView.swift
          ProposalCardView.swift
          AIReviewViewModel.swift
        Memory/
          MemoryPalaceView.swift
          MemoryDetailView.swift
          MemoryCardView.swift
          MemorySearchViewModel.swift
        People/
          PeopleView.swift
          PersonDetailView.swift
          PersonMemoryTimelineView.swift
          PeopleViewModel.swift
        Actions/
          ActionCenterView.swift
          ReminderCardView.swift
          GiftOpportunityCardView.swift
        Ask/
          AskView.swift
          AskViewModel.swift
        Settings/
          SettingsView.swift
          APIKeySettingsView.swift
      SharedUI/
        ThemeChip.swift
        SourceQuoteBlock.swift
        SensitivityBadge.swift
        ConfidenceBadge.swift
        EmptyStateView.swift
        LoadingStateView.swift
        ErrorStateView.swift
      Utilities/
        DateFormatting.swift
        UUIDFactory.swift
        Logger.swift
```

---

## 12. AI provider：DeepSeek contract

### 12.1 Config

设置项：

```text
DEEPSEEK_BASE_URL = https://api.deepseek.com
FAST_MODEL = deepseek-v4-flash
PRO_MODEL = deepseek-v4-pro
```

macOS 用户在 Settings 输入自己的 API key。API key 存 Keychain，不写 SQLite。

### 12.2 模型使用策略

```text
deepseek-v4-flash:
- route_input
- simple extraction
- tag generation
- low-cost summary

deepseek-v4-pro:
- complex mixed input
- long reflection
- gift recommendation
- chat with memory
- weekly review
```

### 12.3 JSON Output 要求

所有结构化 AI 调用必须：

```json
{
  "response_format": { "type": "json_object" }
}
```

prompt 内必须出现 `json` 字样，并提供目标 JSON 示例。

### 12.4 AI 调用失败处理

必须处理：

```text
missing API key
network error
401 / invalid key
rate limit
empty response
invalid JSON
schema validation failure
model unavailable
timeout
```

UI 必须给用户明确状态：

```text
未设置 API key
AI 整理失败，可以稍后重试
AI 返回格式异常，已保存原始输入
网络不可用，原始输入已本地保存
```

---

## 13. AI workflow 1：route_input

输入：raw text。

输出：严格 JSON。

```json
{
  "primary_type": "personal_reflection",
  "secondary_types": ["relationship_memory"],
  "confidence": 0.86,
  "requires_extraction": true,
  "requires_person_linking": true,
  "requires_reminder_generation": false,
  "requires_gift_generation": false,
  "language": "zh",
  "reason_summary": "用户在反思自己和某人的关系感受，包含人际观察。"
}
```

允许类型：

```text
personal_reflection
idea
relationship_memory
person_fact
event
reminder_source
gift_signal
file_note
chat_request
```

---

## 14. AI workflow 2：extract_memory

输入：

```json
{
  "raw_entry_id": "entry_...",
  "raw_text": "...",
  "known_people": [
    { "id": "person_1", "display_name": "Alex", "aliases": ["A"] }
  ],
  "known_themes": ["自我表达", "关系边界"]
}
```

输出：

```json
{
  "entry_summary": "用户反思自己和 Alex 的关系中可能害怕麻烦对方。",
  "memory_proposals": [
    {
      "proposal_type": "memory_atom",
      "memory_type": "personal_reflection",
      "title": "我在人际关系里害怕麻烦别人",
      "summary": "这条记忆反映了用户在和 Alex 的关系里倾向于压下自己的需求。",
      "content": "用户意识到自己可能因为担心麻烦 Alex，而没有表达真实想法。",
      "source_quote": "我好像总是怕麻烦他，所以很多事情没说。",
      "confidence": 0.88,
      "sensitivity": "private",
      "is_ai_inferred": false,
      "related_people": [
        {
          "display_name": "Alex",
          "matched_person_id": "person_1",
          "match_confidence": 0.91,
          "relation_type": "about"
        }
      ],
      "themes": [
        { "name": "自我表达", "confidence": 0.9 },
        { "name": "关系边界", "confidence": 0.82 }
      ],
      "follow_up_questions": [
        "最近哪段关系最容易触发这种感觉？",
        "你担心表达后对方会有什么反应？"
      ],
      "suggested_actions": []
    }
  ],
  "person_fact_proposals": [],
  "reminder_proposals": [],
  "gift_signal_proposals": [],
  "conflicts": [],
  "follow_up_questions": [
    "要不要把这条记忆关联到 Alex 的关系时间线？"
  ]
}
```

### 14.1 抽取规则

System prompt 必须包含：

```text
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
```

---

## 15. AI workflow 3：approve_pending_update

用户 approve 后才写入。

处理逻辑：

```text
1. load pending_update
2. parse payload_json
3. validate proposal_type
4. if memory_atom:
   - create memory_atoms
   - create or link themes
   - link people if person exists
   - if person match ambiguous, require user selection
5. mark pending_update.status = approved
6. write audit_events
```

如果用户 edit：

```text
1. save edited payload_json
2. status remains pending or becomes edited
3. approve edited payload
```

如果 reject：

```text
1. status = rejected
2. no final memory write
3. keep raw_entry
```

---

## 16. AI workflow 4：chat_with_memory

Ask 页面和 Memory Detail 的继续讨论都用这个。

流程：

```text
user query
→ retrieve relevant memory_atoms / people / themes / reminders
→ build grounded context
→ call model
→ answer with source-backed summary
→ if new insight appears, return optional pending updates
```

禁止：

```text
把整个数据库塞进 prompt
无来源地回答“你最近一定怎样”
心理诊断
自动写入新记忆
```

输出：

```json
{
  "answer": "基于已保存的记忆，你最近多次提到自我表达和害怕麻烦别人。和 Alex 相关的记录里，这个主题出现过两次。",
  "used_memory_ids": ["mem_1", "mem_2"],
  "source_summaries": [
    {
      "memory_id": "mem_1",
      "title": "我在人际关系里害怕麻烦别人",
      "source_quote": "我好像总是怕麻烦他，所以很多事情没说。"
    }
  ],
  "new_pending_updates": []
}
```

---

## 17. AI workflow 5：gift recommendation

礼物推荐必须基于记忆，不允许泛泛推荐。

输入：

```json
{
  "person_id": "person_1",
  "occasion": "birthday",
  "budget_min": 100,
  "budget_max": 300,
  "style": "thoughtful but not too intimate",
  "constraints": ["no_food"]
}
```

检索：

```text
person facts
related gift_signal memories
interests
dislikes
dietary restrictions
previous gifts
relationship level
recent life events
boundaries
```

输出：

```json
{
  "recommendations": [
    {
      "title": "小型陶艺体验课",
      "category": "experience",
      "estimated_budget": "200-300",
      "match_score": 86,
      "surprise_score": 74,
      "risk_level": "medium",
      "why_it_fits": "她最近提到在学陶艺，体验型礼物贴合当前兴趣。",
      "evidence_memory_ids": ["mem_123"],
      "risk_reason": "需要确认她是否已有固定课程。",
      "avoid_if": "她只是短期体验，不打算继续学。",
      "soft_probe_message": "你最近陶艺课还在上吗？有没有什么工具或体验特别想试？"
    }
  ],
  "avoid": [
    {
      "item": "食品礼盒",
      "reason": "用户限制 no_food，且该朋友有饮食偏好记录。"
    }
  ],
  "missing_info_questions": [
    "她更喜欢实物还是体验？"
  ]
}
```

---

## 18. 页面规格

### 18.1 Capture

目标：让用户不用想格式，直接说。

文案：

```text
今天想记点什么？
可以是一段感悟、一次聊天、一个人、一个提醒、一个礼物线索，或者一个文件。
```

功能：

- 大输入框。
- 快捷 chip：`感悟`、`朋友近况`、`灵感`、`提醒`、`礼物线索`、`随便说说`。
- 保存原始输入到 RawEntry。
- 如果有 API key，调用 route_input + extract_memory。
- 如果没有 API key，只保存 RawEntry，并提示去 Settings 设置。
- AI 完成后创建 PendingUpdate，并跳转或提示到 AI Review。

状态：

```text
idle
saving_raw_entry
extracting
created_proposals
saved_without_ai
failed_but_raw_saved
```

### 18.2 AI Review

目标：用户确认 AI 结果。

卡片类型：

```text
PersonalReflectionProposalCard
IdeaProposalCard
RelationshipMemoryProposalCard
PersonFactProposalCard
EventProposalCard
ReminderProposalCard
GiftSignalProposalCard
ConflictProposalCard
FollowUpQuestionCard
```

每张卡显示：

```text
类型
标题
摘要
原文引用
置信度
敏感度
关联人物
关联主题
AI 是否推断
操作：确认 / 编辑 / 忽略 / 继续讨论
```

不要只给“确认全部”。必须支持逐条确认。

### 18.3 Memory Palace

目标：个人记忆线的核心页面。

筛选：

```text
全部
感悟
灵感
人际
事件
礼物
文件
私密
```

每张 MemoryCard 显示：

```text
title
summary
type badge
people chips
theme chips
sensitivity badge
created_at
source_quote preview
```

详情页：

```text
title
summary
content
source_quote
related_people
related_themes
related_memories
follow_up_questions
continue discussion
create reminder from memory
create gift signal from memory
archive
```

### 18.4 People

目标：朋友档案由记忆构成，而不是孤立字段。

Person detail tabs：

```text
Overview
Memories
Timeline
Facts
Preferences
Boundaries
Gifts
Reminders
Files
```

Overview 显示：

```text
基本信息
最近相关记忆
AI 可解释摘要
生日和提醒
礼物线索
沟通边界
来源支持的事实
```

Facts 里的每条事实必须能显示：

```text
source memory
source quote
confidence
last confirmed date
```

### 18.5 Actions

目标：统一所有需要做的事。

显示：

```text
待确认
今天提醒
即将到来
生日和纪念日
礼物机会
该联系的人
关系风险
文件待处理
```

### 18.6 Ask

目标：问自己的记忆系统。

示例 placeholder：

```text
问问你的记忆：我最近反复在想什么？我和 Alex 的关系有什么变化？谁不吃香菜？
```

回答必须显示：

```text
回答
使用了哪些记忆
哪些地方没有足够证据
是否建议生成新的待确认记忆
```

### 18.7 Settings

必须包含：

```text
DeepSeek API Key
模型选择：fast / pro
测试 API key
清除 API key
敏感记忆默认隐藏开关
导出本地数据
删除全部本地数据
开发者日志开关
```

---

## 19. 搜索和检索策略

Phase 1 只做本地搜索，不做 embeddings。

优先级：

```text
1. exact person/theme filter
2. FTS5 full text search if available
3. LIKE fallback
4. recency boost
5. type/sensitivity filters
```

Ask with Memory 的 retrieval 不要超过上下文预算。

建议：

```text
最多取 12 条 memory_atoms
最多取 5 个人物事实
最多取 5 个主题
优先 confirmed，排除 archived
默认排除 sensitive，除非用户明确允许
```

---

## 20. 本地隐私和安全要求

### 20.1 API key

- API key 只存在 Keychain。
- SQLite 不保存 API key。
- 日志不打印 API key。
- crash logs 不包含 API key。
- UI 中默认 mask API key。

### 20.2 AI 请求

- 只发送当前任务需要的最小上下文。
- 不发送整个 SQLite。
- 敏感记忆默认不参与 Ask retrieval，除非用户打开开关。
- `ai_runs` 默认只保存 input_summary，不保存完整 prompt。调试模式可以保存更详细 output，但不能保存 API key。

### 20.3 SQLite

- 本轮可以先不做 SQLCipher，但要在 docs 中标记风险。
- 提供“删除全部本地数据”。
- 提供“导出数据”，导出文件默认不包含 API key。

---

## 21. 测试要求

必须添加或更新测试。

### 21.1 Fixture

创建：

```text
macos/Tests/Fixtures/input_zh_reflection.json
macos/Tests/Fixtures/input_friend_fact.json
macos/Tests/Fixtures/input_mixed_relationship.json
macos/Tests/Fixtures/input_gift_signal.json
macos/Tests/Fixtures/input_reminder.json
macos/Tests/Fixtures/input_sensitive.json
macos/Tests/Fixtures/extract_memory_valid_response.json
macos/Tests/Fixtures/extract_memory_invalid_response.json
```

### 21.2 Unit tests

覆盖：

```text
MigrationManager applies schema v2
RawEntryRepository creates and fetches raw entry
PendingUpdateRepository creates pending proposals
approve_pending_update creates memory_atoms
theme auto-create and link
person link behavior
AIJSONParser valid response
AIJSONParser invalid response
KeychainService does not expose key in logs
Memory search filters by type/person/theme
```

### 21.3 Manual QA script

创建：

```text
docs/MACOS_MANUAL_QA.md
```

测试脚本：

```text
1. fresh install opens successfully
2. enter DeepSeek API key
3. test API key
4. capture a personal reflection
5. AI Review shows proposal
6. approve proposal
7. Memory Palace shows memory
8. create or select a person
9. capture friend-related note
10. link memory to person
11. person detail shows related memory
12. ask a memory question
13. answer shows source memories
14. reject a proposal
15. sensitive memory is hidden by default
16. delete local data
```

---

## 22. Build and verification

Use existing scripts where possible.

Expected commands:

```bash
./script/build_and_run.sh --verify
swift test
swift build
```

If current repo uses a different macOS build command, discover it during audit and update docs.

Do not mark done until macOS target builds.

---

## 23. 开发阶段

### Phase 0: Audit

先做：

```text
1. inspect repository structure
2. identify current macOS entry point
3. identify current SQLite schema
4. identify current Keychain service
5. identify existing AI Inbox / PendingUpdate logic
6. identify current build/test commands
7. write docs/CODEX_AUDIT.md
```

`docs/CODEX_AUDIT.md` 必须包括：

```text
current macOS files
current database files
current AI files
current UI sections
risks
implementation plan
```

### Phase 1: Docs and schema

创建或更新：

```text
docs/MEMORY_PROTOCOL.md
docs/AI_CONTRACT.md
docs/NATIVE_V1_SCOPE.md
docs/DESIGN_SYSTEM.md
docs/MACOS_MANUAL_QA.md
```

实现 SQLite schema v2 migration。

### Phase 2: Domain and repositories

实现：

```text
RawEntry
MemoryAtom
PendingUpdate
Theme
repositories
migration tests
```

### Phase 3: AI workflows

实现：

```text
DeepSeekClient
PromptBuilder
AIWorkflowService.routeInput
AIWorkflowService.extractMemory
AIJSONParser
AIContractValidator
```

先用 mocked AI fixtures 测试。真实 DeepSeek 调用通过 Settings API key 测试。

### Phase 4: Capture + AI Review

实现完整闭环：

```text
Capture input
save RawEntry
run extraction
create PendingUpdates
AI Review cards
approve/edit/reject
create MemoryAtom
```

### Phase 5: Memory Palace + Ask

实现：

```text
memory list
filters
search
memory detail
continue discussion
ask with memory retrieval
source display
```

### Phase 6: People integration

实现：

```text
person detail related memories
timeline from memory_atoms
facts with source quotes
gift signals from memories
reminders from memories
```

### Phase 7: Polish and QA

完成：

```text
visual consistency
empty states
error states
manual QA
build verification
README update
```

---

## 24. 第一批可执行任务清单

Codex 应按顺序执行：

```text
[ ] Create docs/CODEX_AUDIT.md after repository inspection.
[ ] Create docs/MEMORY_PROTOCOL.md.
[ ] Create docs/AI_CONTRACT.md.
[ ] Create docs/NATIVE_V1_SCOPE.md.
[ ] Create docs/DESIGN_SYSTEM.md.
[ ] Create docs/MACOS_MANUAL_QA.md.
[ ] Add SQLite schema v2 migration.
[ ] Add RawEntry model and repository.
[ ] Add MemoryAtom model and repository.
[ ] Extend PendingUpdate to generic proposal_type + payload_json.
[ ] Add Theme model and repository.
[ ] Add memory_person_links and memory_theme_links support.
[ ] Add AI models for route_input and extract_memory.
[ ] Add PromptBuilder.
[ ] Add DeepSeekClient JSON call support.
[ ] Add AIJSONParser and validation.
[ ] Add CaptureView and CaptureViewModel.
[ ] Add AIReviewView and ProposalCardView.
[ ] Add approve/edit/reject behavior.
[ ] Add MemoryPalaceView.
[ ] Add MemoryDetailView.
[ ] Add local memory search.
[ ] Add AskView with retrieval-backed answer.
[ ] Update PersonDetailView to show related memories.
[ ] Update Settings for DeepSeek key and model selection.
[ ] Add tests and fixtures.
[ ] Run macOS build verification.
[ ] Update README with macOS-first instructions.
```

---

## 25. Acceptance criteria

This task is complete only if all criteria pass:

1. macOS app builds successfully.
2. User can enter free-form text in Capture.
3. RawEntry is saved locally before AI call.
4. If API key is missing, raw entry remains saved and UI gives clear error.
5. With API key, AI extraction creates PendingUpdate records.
6. AI Review shows proposal cards with source quote, confidence and sensitivity.
7. User can approve a personal reflection proposal into MemoryAtom.
8. User can reject a proposal without mutating final data.
9. User can edit a proposal before approving.
10. Memory Palace lists confirmed MemoryAtoms.
11. Memory Detail shows source quote, related people, related themes and continue discussion.
12. User can link a memory to an existing person.
13. Person detail shows related MemoryAtoms.
14. Ask page answers using retrieved memory context and displays used sources.
15. Sensitive memories are hidden or visually protected by default.
16. DeepSeek API key is stored in Keychain only.
17. SQLite does not contain the API key.
18. Tests cover migrations, repositories, AI JSON parsing and approval logic.
19. Documentation explains Memory Protocol and macOS-first scope.
20. No AI workflow directly mutates confirmed people, reminders, gifts or memory records without PendingUpdate approval.

---

## 26. Future roadmap after macOS V1.5

Do not implement these now, but keep architecture ready.

### V1.6: iOS companion

- Reuse Memory Protocol.
- Reuse AI contract.
- Mobile-first Capture.
- Voice input.
- iOS reminders / notifications.

### V1.7: File memory

- Markdown / text / CSV import.
- PDF text extraction.
- Chat screenshot OCR after privacy review.
- File-derived MemoryAtoms.

### V1.8: Relationship graph as memory graph

- Nodes: Person, MemoryAtom, Theme, Group.
- Edges: mentions, about, belongs_to, related_to, inferred.
- Graph becomes navigation, not decoration.

### V2: Sync

- Optional encrypted sync.
- Keep DeepSeek key device-local.
- Conflict resolution for MemoryAtoms and PendingUpdates.

### V2.1: App Intents and system integration

- Add Capture Memory intent.
- Add Ask Memoria intent.
- Add Create Reminder From Memory intent.
- Add Spotlight search integration if appropriate.

---

## 27. Codex execution instruction

Begin now.

First, inspect the repo. Do not make broad changes before writing `docs/CODEX_AUDIT.md`.

Then implement Phase 1 to Phase 4 as the first deliverable:

```text
Phase 1: docs + schema
Phase 2: domain + repositories
Phase 3: AI workflow skeleton with mocked fixtures
Phase 4: Capture + AI Review approval loop
```

Stop after Phase 4 if the diff becomes too large, but make sure the macOS app builds and the Capture → AI Review → approve → MemoryAtom path works with mocked AI output. If real DeepSeek integration is possible within the current codebase, add it behind Settings API key, but do not block the local mocked workflow on network access.

Remember: the goal is not to add more screens. The goal is to make Memoria’s memory core real.
