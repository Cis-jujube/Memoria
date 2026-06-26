# Memoria AI 分类误判查缺补漏与优化方案

日期：2026-06-19
状态：v16，已通过第十六轮三角色独立盲审（哲学 96、人际 97、行程 97），可进入实现计划。
适用范围：当前 macOS 原生实现。Web 只作为视觉/API 参考。本方案不要求立即修改数据库 schema、认证、同步或云端部署；AI 仍只生成 `PendingUpdate`，确认写入必须经过用户在整理台批准。

## 1. 一句话目标

Memoria 不应该用“出现了我/朋友名/时间词/礼物词”这种死规则分类，而应该先理解这句话的语义结构，再决定要保存什么、提醒什么、更新谁的档案、沉淀哪段关系、捕捉什么机会。

核心修正：

- “我要和 Jason 下午约个饭”是未来社交行程，不是自我反思，也不应自动设置 `sensitivity=sensitive` 或 `visibility_preference=user_marked_private`。
- “今天准备考试时，我发现自己有点焦虑，想记一下这个状态”是自我反思候选；若只是“一次性考试焦虑”且没有保存/复盘意图，默认只作低优先级情绪上下文。
- “Jason 最近准备面试，我明天问问他”同时包含朋友当前状态和用户跟进行动，主卡应服务下一步动作。

## 2. 第一轮盲审打回结论

三位独立评审均低于 95 分，因此 v0 被打回重写。

| 评审角色 | 分数 | 打回重点 |
| --- | ---: | --- |
| 哲学教授 | 88 | 概念层级混杂：话语行为、语义对象、存储实体、UI 分区、下一步动作不能混为一个主类。 |
| 人际管理大师 | 86 | 朋友档案仍像静态资料库，没有充分转化为人脉资产、关系机会、风险和跟进动作。 |
| 行程规划师/私人管家 | 88 | 行程可执行性定义不够硬，缺少时间确定性、承诺程度、取消/改期、重复事项和 deadline/task/event 区分。 |

本轮重写原则：

1. 严格分离 `semantic_primary`、`workflow_primary`、`storage_targets`。
2. 先抽取正交语义字段，再决定整理台优先处理哪张卡。
3. 行程类必须区分 schedule candidate、executable reminder、contextual guard。
4. 行程协议必须保留时间表达来源、解析上下文、提醒时间和事件/截止/任务边界。
5. 朋友与关系信息必须沉淀为可复用人脉资产，并包含机会优先级、网络路径和生命周期。
6. 不确定时不强行选边，生成候选分类、阻塞决策和确认问题。

## 3. 当前产品不变量

- `RawEntry` 保存用户原文，不被 AI 覆盖。
- AI 只能提出结构化 `PendingUpdate`。
- `PendingUpdate` 进入整理台，由用户批准、编辑或拒绝。
- 批准后才生成 confirmed `MemoryAtom`、朋友档案更新、提醒、关系边或礼物线索。
- 敏感、展示偏好和低调审核标记只用于真实敏感内容，不用于普通社交安排。
- 一个输入可以生成多个待确认建议，但主卡片必须服务用户下一步最自然的动作。

## 4. 正交分类字段

不要一开始就问“这属于哪个主类”。先按固定顺序判定，再拆正交字段。

固定判定链：

```text
utterance -> propositional_content -> intentional_attitude -> domain_object -> practical_affordance -> workflow_primary -> storage_targets
```

含义：

1. `utterance`：用户实际说了什么，必须保留原文。
2. `propositional_content`：这句话陈述或设想的命题内容。
3. `intentional_attitude`：用户对命题的态度，例如相信、担心、希望、打算、请求。
4. `domain_object`：命题真正指向的对象，例如用户状态、朋友事实、关系、未来行动、文件来源。
5. `practical_affordance`：系统能提供的实践动作，例如保存、提醒、引荐机会、风险提示、追问。
6. `workflow_primary`：整理台优先展示哪类卡。
7. `storage_targets`：用户批准后写入哪里。

后层不能重写前层：`workflow_primary=reminder_source` 不代表 `semantic_primary` 一定是日程；`asset_value=resource_intelligence` 或 `opportunity_type=intro` 也不能把普通朋友事实改写成商业机会。

| 字段 | 含义 | 典型值 |
| --- | --- | --- |
| `illocutionary_force` | 用户这次发话对系统/记录的表层行为 | `assertion`, `planning_declaration`, `directive_to_system`, `reported_request`, `question`, `correction`, `cancellation`, `reschedule`, `preference_expression` |
| `domain_frame` | 语义领域 | `self_state`, `friend_profile`, `relationship`, `schedule`, `gift_touchpoint`, `file_source` |
| `domain_object` | 具体对象；`episodic_self_state` 是 `domain_frame=self_state` 的子类型，不是 workflow/storage 枚举 | `episodic_self_state`, `durable_self_pattern`, `person_fact`, `relationship`, `schedule`, `file_source` |
| `operation` | 系统应考虑的操作 | `create`, `update_existing`, `cancel_existing`, `reschedule_existing`, `disable_reminder`, `link_source`, `ask_confirmation`, `none` |
| `semantic_roles` | 行动者、体验者、欲望主体、受益人、信息来源 | `actor`, `experiencer`, `target_person`, `desire_owner`, `beneficiary`, `source_speaker`, `source_file` |
| `intentional_layers` | 多层意向结构 | `attitude_holder`, `intentional_mode`, `direction_of_fit`, `aboutness_target`, `propositional_content`, `affective_bearer`, `practical_target` |
| `temporal_status` | 时间状态 | `past`, `present_state`, `future`, `recurring`, `timeless`, `unknown` |
| `time_expression_kind` | 时间表达类型 | `exact_datetime`, `absolute_date`, `relative_date`, `relative_window`, `fuzzy_window`, `event_relative`, `recurring_rule`, `missing_time` |
| `schedule_execution_state` | 日程是否可执行 | `not_schedule`, `draft_schedule_candidate`, `executable_reminder`, `executable_schedule_item`, `contextual_guard_candidate`, `anchored_contextual_guard`, `existing_item_mutation` |
| `actionability` | 是否可执行 | `none`, `optional`, `tentative`, `committed`, `ask_confirmation`, `cancel_existing`, `reschedule_existing`, `update_existing`, `disable_reminder` |
| `storage_targets` | 批准后可能沉淀的位置，必须是数组 | `personal_reflection`, `person_fact`, `relationship_memory`, `reminder_source`, `gift_signal`, `file_note` |
| `retention_policy` | 不写入业务对象时如何保留 | `write_candidate`, `source_context_only`, `context_only`, `discard_after_review` |
| `opportunity_type` | 关系经营机会类型，不是 confirmed 存储本体 | `none`, `gift`, `congratulate`, `comfort`, `thanks`, `intro`, `follow_up`, `risk_reduction`, `referral_request` |
| `asset_value` | 对用户的长期价值，只作为排序/解释信号 | `self_understanding`, `profile_completeness`, `relationship_signal`, `opportunity`, `risk_reduction`, `resource_intelligence`, `source_traceability` |
| `sensitivity` | 内容敏感度 | `normal`, `sensitive` |
| `sensitivity_domain` | 敏感领域 | `none`, `health`, `mental_health`, `financial`, `romantic`, `family_conflict`, `identity`, `trauma`, `relationship_risk` |
| `severity` | 严重程度 | `none`, `mild`, `moderate`, `high`, `crisis` |
| `privacy_display_risk` | 展示时可能造成的隐私风险 | `none`, `low`, `medium`, `high` |
| `visibility_preference` | 展示偏好，不能由 AI 直接确认 | `default`, `suggest_limited`, `user_marked_private` |
| `requires_discreet_review` | 是否在整理台低调展示 | `true`, `false` |
| `needs_slot_confirmation` | 是否缺字段或存在歧义，不能执行 | `true`, `false` |
| `requires_user_approval` | 是否仍需用户批准写入；`PendingUpdate` 永远为 true | `true` |

主类选择是最后一步。主类不是“哪个关键词最强”，而是“用户最可能希望系统保存、提醒、更新或协助的对象是什么”。

canonical schema 只允许以下字段决定分类和路由：

- `proposition_units`
- `semantic_primary_unit_id`
- `workflow_primary_unit_id`
- `workflow_primary`
- `secondary_workflows`
- `storage_targets`
- `retention_policy`
- `schedule_*` 字段
- `opportunity_type` 和关系机会字段

派生/兼容字段只能由 canonical 字段计算，不能反向参与判定：

- `primary_type`
- `secondary_types`
- `semantic_primary` 字符串摘要
- `candidate_workflow`
- `candidate_storage_targets`
- UI section/review category

`intentional_layers.intentional_mode` 的典型值包括 `belief/assertion`, `desire`, `intention`, `fear`, `preference`, `request`。`direction_of_fit` 用来区分“描述世界”还是“让世界符合计划”：朋友事实通常是 `mind_to_world`，待办/提醒通常是 `world_to_mind`，情绪反思可能是 `self_interpretation`。

`illocutionary_force` 和 `intentional_mode` 必须分开：

| 输入 | `illocutionary_force` | `intentional_mode` | 判定 |
| --- | --- | --- | --- |
| 我要和 Jason 吃饭 | `planning_declaration` | `intention` | 用户声明未来计划；承诺强度另由 `commitment_level` 判定 |
| 下午提醒我和 Jason 吃饭 | `directive_to_system` | `request` | 用户要求系统创建提醒候选 |
| May 让我周五前发材料 | `reported_request` | `request` held by May | 他人请求形成用户 deadline 候选 |
| 我觉得 Alex 不吃香菜 | `assertion` | `belief/assertion` with lower confidence | 朋友事实，非反思 |
| 我怕 Jason 忘了材料 | `assertion` | `fear` as motivation | 担忧解释跟进风险，非自我模式 |

`illocutionary_force`、`intentional_mode`、`commitment_level` 三者不得互相替代：

| 字段 | 判定对象 | 例子 |
| --- | --- | --- |
| `illocutionary_force` | 用户这句话对系统/记录在做什么 | assertion/planning_declaration/directive/correction/cancellation |
| `intentional_mode` | 命题内部的态度 | belief/desire/intention/fear/request |
| `commitment_level` | 计划或行动的确定程度 | committed/intended/tentative/conditional/suggested |
| `embedded_speech_act` | 命题内被转述的话语行为 | May asked / Jason said / screenshot shows |

如果同一句包含多个命题，必须先拆成 `proposition_units`，再分别选择语义主命题和工作流主命题。不得把多个命题合并成一个 `semantic_primary`。

切分规则：

| 结构 | 切分方式 |
| --- | --- |
| 并列 | “Jason 面试，我明天问他”切成状态命题和用户行动命题 |
| 转折 | “想吃饭但有点尴尬”切成计划命题和情绪上下文 |
| 因果/动机 | “我怕他忘了，所以提醒我”切成担忧动机和提醒 directive |
| 条件 | “如果有空就约 May”切成条件前件和行动后件，后件 `commitment_level=conditional` |
| 否定 | 否定作用域只作用于对应命题，不扩散到全句 |
| 来源/证据 | “我听说/我觉得/截图里”切成 evidentiality，不改变命题对象 |
| 情绪 + 外部风险 | 若 `aboutness_target` 是他人/材料/事件风险，情绪为 motivation；若指向用户长期模式，才是 self pattern |

`proposition_units` 最低字段：

| 字段 | 含义 |
| --- | --- |
| `unit_id` | 稳定 id，如 `u1` |
| `source_span` | 对应原文片段 |
| `propositional_content` | 单一命题内容 |
| `attitude_holder` | 谁持有该态度 |
| `intentional_mode` | belief/desire/intention/fear/request/preference |
| `embedded_speech_act` | none/reported_request/reported_assertion/reported_preference |
| `evidentiality` | direct_observation/inference/hearsay/file_source/user_guess |
| `confidence_basis` | 为什么是该置信度 |
| `domain_object` | episodic_self_state/durable_self_pattern/person_fact/relationship/schedule/file_source |
| `candidate_workflow` | 这个 unit 自身最自然的工作流候选 |
| `candidate_storage_targets` | 这个 unit 可写入的位置 |
| `proposal_kind` | write_candidate/workflow_candidate/context_only/blocker |

输入级别再输出：

| 字段 | 规则 |
| --- | --- |
| `semantic_primary_unit_id` | 语义主命题；回答“这句话主要在说什么” |
| `workflow_primary_unit_id` | 工作流主命题；回答“整理台先处理什么”；纯上下文输入可为 null |
| `secondary_unit_ids` | 可产生副卡或上下文的命题 |
| `workflow_primary` | 唯一主卡，不允许写成 A + B；纯上下文输入用 null，不写 `none/context_only` |
| `secondary_workflows` | 可选副卡数组 |
| `storage_targets` | 所有已批准后可写入的位置数组 |

no-workflow 哨兵：如果输入只有临时情绪、来源背景、弱证据或解释性 affordance，且没有可处理主卡，则必须输出 `workflow_primary=null`、`workflow_primary_unit_id=null`、`secondary_workflows=[]`、`retention_policy=context_only` 或 `source_context_only`。不得用 `workflow_primary=none/context_only` 伪装成主卡，也不得把 `latent_relationship_affordance` 写入 `workflow_primary`、`secondary_workflows`、`storage_targets` 或 `card_type`。

`semantic_primary_unit_id` 选择矩阵：

| 情况 | 选择规则 |
| --- | --- |
| 单命题输入 | 该 unit 是 semantic primary 和 workflow primary |
| 显式 directive + 被引用事实 | semantic primary 选被陈述/引用的事实；workflow primary 选 directive |
| 事实 + 用户跟进动作 | semantic primary 选事实；workflow primary 选用户动作 |
| 计划 + 短暂情绪 | semantic primary 选计划；情绪 unit 仅 `context_only`，除非用户明确复盘 |
| 自我长期模式 + 事件证据 | semantic primary 选自我长期模式；事件作为证据 |
| 关系边界 + 场景 | semantic primary 选边界；场景作为作用域 |
| 文件来源 + 文件内容事实 | semantic primary 选内容事实；文件来源进入 source context |

若语法主干、信息焦点和工作流动作冲突，按以下顺序选择 semantic primary：显式被断言的事实/状态 > 用户长期自我模式或边界 > 关系事件 > 计划动作 > 背景/来源/情绪动机。workflow primary 另按主卡规则选择。

### 4.1 语义主对象、工作流主卡、存储目标必须分离

每条结果必须同时区分三层：

| 层级 | 字段 | 定义 |
| --- | --- | --- |
| 语义层 | `semantic_primary` | 这句话在语义上主要陈述、表达、评价或请求的对象。 |
| 工作流层 | `workflow_primary` | 整理台中最应该优先让用户处理的卡片。 |
| 存储层 | `storage_targets` | 用户批准后可能写入的一个或多个位置。 |

`workflow_primary` 可以服务下一步动作，但不得反过来改写 `semantic_primary`。

`semantic_primary` 是自然语言命题的主对象；`primary_type` 是系统类型投影。两者可以不同：一句话语义上讲的是“Alex 的生日事实”，但工作流上可以同时提出生日档案卡和提前提醒候选。

当用户显式给出对系统的 directive，例如“提醒我、帮我记、取消、改到、别再提醒”，`workflow_primary` 默认优先服务该 directive；被 directive 引用的事实进入副卡或前置确认。例外：directive 依赖的事实完全缺失且不可解析时，主卡仍是 directive 候选，但 `blocked_decision` 必须说明缺什么。

例子：

| 输入 | `proposition_units` | semantic/workflow unit | `workflow_primary` | `secondary_workflows` |
| --- | --- | --- | --- | --- |
| Jason 最近准备面试，我明天问问他 | `u1=Jason 正在准备面试`; `u2=用户明天问 Jason` | semantic=`u1`, workflow=`u2` | `reminder_source/follow_up` | `person_fact/current_state` |
| Alex 生日是 8 月 3 日，提前一周提醒我 | `u1=Alex 生日事实`; `u2=用户要求提前一周提醒` | semantic=`u1`, workflow=`u2` | `reminder_source/anniversary_reminder` | `person_fact/anniversaries` |
| 我怕 Jason 忘了材料 | `u1=Jason/材料存在跟进风险`; `u2=用户担忧` | semantic=`u1`, workflow=`u1` | `reminder_source/follow_up` | `u2` is motivation context only |
| 我不太想再和 Chris 单独吃饭 | `u1=用户关系边界`; `u2=Chris 单独吃饭场景` | semantic=`u1`, workflow=`u1` | `personal_reflection` | `relationship_memory/risk_boundary` |

### 4.2 认识论标记、情绪内容和自我反思

`我觉得/我猜/我听说/我怕/我担心` 先作为 `evidentiality` 或 `confidence_modifier` 处理，而不是自动归入自我反思。

进入 `personal_reflection` 需要同时满足：

1. 补语内容指向用户自己的状态、性格、习惯、价值判断、边界或长期模式。
2. 该状态本身具有被长期检索的价值。
3. 句子的主要功能不是降低朋友事实置信度、解释提醒动机或表达执行意图。

对比：

| 输入 | 解释 |
| --- | --- |
| 我觉得 Alex 不吃香菜 | `我觉得` 是证据强度，主内容是 Alex 的忌口。 |
| 我怕 Jason 忘了材料 | `我怕` 是提醒动机，主内容是材料跟进风险。 |
| 我怕自己总是在关系里退缩 | 补语指向用户长期关系模式，进入自我反思。 |

### 4.3 歧义分类

不确定性要被显式记录，而不是强行选边。

| 歧义类型 | 字段值 | 示例 |
| --- | --- | --- |
| 指代歧义 | `referential_ambiguity` | 他、她、TA、同名 Jason |
| 时间歧义 | `temporal_ambiguity` | 下午、之后、见面前 |
| 模态歧义 | `modal_ambiguity` | 可能、要不、如果有空 |
| 作用域歧义 | `scope_ambiguity` | 否定、提醒、取消、改期作用于哪个对象 |
| 来源歧义 | `source_ambiguity` | 用户亲知、朋友转述、文件来源、截图推断 |
| 愿望主体歧义 | `desire_owner_ambiguity` | 想要、喜欢、需要是谁的愿望 |

出现这些歧义时，`needs_slot_confirmation=true`，并给出候选分类和一句面向用户的确认问题。

歧义输出必须包含：

```json
{
  "ambiguous_slots": ["raw_time_expression", "target_person"],
  "candidate_interpretations": [
    {
      "workflow_primary": "reminder_source/follow_up",
      "reason": "用户可能想创建跟进提醒"
    },
    {
      "workflow_primary": "person_fact/current_state",
      "reason": "也可能只是记录朋友状态"
    }
  ],
  "blocked_decision": "cannot_create_executable_reminder",
  "confirmation_question": "你想让我把这条设成提醒，还是只记录 Jason 最近准备面试？"
}
```

硬规则：如果 `desire_owner != actor`，不能自动生成用户自己的日程或偏好。`May 想暑假旅行` 是 May 的愿望/偏好；最多生成朋友事实、礼物/关系机会或确认问题，不得直接创建“用户暑假旅行”。

### 4.4 隐私与敏感性

| 值 | 定义 |
| --- | --- |
| `normal` | 普通事实、普通行程、普通朋友偏好。 |
| `sensitive` | 涉及健康、心理危机、财务、恋爱、家庭冲突、身份、创伤、强关系风险等内容。 |

普通社交安排默认 `sensitivity=normal`、`visibility_preference=default`、`requires_discreet_review=false`。自我情绪不自动等于 `sensitive`，但焦虑、健康、冲突、创伤等可触发 `sensitivity=sensitive` 或 `requires_discreet_review=true` 候选，并要求用户确认展示方式。AI 不应把“用户不希望展示”当作已知事实；只有用户明确标记后才写 `visibility_preference=user_marked_private`。

隐私/敏感性判定矩阵：

| 输入类型 | `sensitivity` | `sensitivity_domain` | `severity` | `privacy_display_risk` | `visibility_preference` | `requires_discreet_review` |
| --- | --- | --- | --- | --- | --- | --- |
| 普通社交安排，如约饭 | `normal` | `none` | `none` | `none` | `default` | `false` |
| 普通轻微尴尬/紧张，附着于计划 | `normal` | `none` | `mild` | `none` | `default` | `false` |
| 一次性考试焦虑，未要求长期保存 | `normal` | `mental_health` | `mild` | `low` | `default` | `false` |
| 反复心理模式或明确自我复盘 | `sensitive` only if content warrants | `mental_health` 或 `relationship_risk` | `mild/moderate` | `medium` | `suggest_limited` | `true` |
| 健康、财务、家庭冲突、创伤、身份 | `sensitive` | 对应 domain | `moderate/high/crisis` | `high` | `suggest_limited` | `true` |
| 用户明确说“设为私密/别展示” | 按内容判定 | 按内容判定 | 按内容判定 | `high` | `user_marked_private` | `true` |

硬负断言：`我想下午和 Jason 吃饭但有点尴尬` 的 workflow primary 仍是 `reminder_source/event`；`storage_targets` 不得包含 `personal_reflection`；`sensitivity=normal`；`sensitivity_domain=none`；`privacy_display_risk=none`；`visibility_preference=default`；`requires_discreet_review=false`。

## 5. 主卡选择规则

### 5.1 保存对象优先于 UI 分区

UI 分区只是整理台入口，不是语义本体。主卡选择顺序：

1. 用户明确要求执行、跟进、提醒、取消、改期：主卡倾向 `reminder_source`。
2. 用户明确陈述朋友稳定事实或短期状态：主卡倾向 `person_fact`。
3. 句子主体是两人/多人关系：主卡倾向 `relationship_memory`。
4. 用户在记录自己的内在状态、价值判断、边界或长期模式：主卡倾向 `personal_reflection`。
5. 出现愿望、礼物、祝贺、感谢、安慰等关系经营触点但没有用户行动意图：主卡仍是 `person_fact`、`relationship_memory`、`gift_signal/touchpoint` 或 `reminder_source`；只能附 `latent_relationship_affordance=<type>` 作为解释。只有用户明确表达计划、购买、提醒、问候、感谢、回报、引荐、跟进或请求时，`workflow_primary` 或 `secondary_workflows` 才可进入工作流级 `relationship_opportunity/<opportunity_type>`；它不是 `storage_targets`。
6. 信息主要来自文件或截图：保留 `source_context`；只有来源本身有独立价值时才主卡为 `file_note`。

### 5.2 冲突时生成主副提案

当保存对象和下一步动作冲突，不要强行压成一个类。

| 输入 | 主卡 | 副卡 | 原因 |
| --- | --- | --- | --- |
| Jason 最近准备面试，我明天问问他 | `reminder_source/follow_up` | `person_fact/current_state` | 用户下一步动作是明天跟进；朋友状态也有档案价值 |
| Alex 生日是 8 月 3 日，提前一周提醒我 | `reminder_source/anniversary_reminder` | `person_fact/anniversaries` | “提醒我”是显式 directive；生日事实为提醒提供依据 |
| 下周和 May 听讲座，她喜欢建筑史 | `reminder_source/event` | `person_fact/interests` | 行程主导，兴趣可沉淀 |
| 我和 Alex 聊完发现自己太急了 | `personal_reflection` | `relationship_memory` | 核心是自我理解，互动是证据 |
| May 说想试拍立得，生日快到了 | `gift_signal/touchpoint` | `person_fact/interests`, `person_fact/anniversaries` | 只有愿望和生日事实，没有用户计划/购买/提醒意图，不进入机会生命周期；`latent_relationship_affordance=gift` 只能作解释字段，不是副卡 |

### 5.3 不确定时不硬判

以下情况必须 `needs_slot_confirmation=true`：

- 人名或代词不明确：他、她、TA、同名朋友。
- 时间不完整：下午、下周、有空时、之后、见面前。
- 计划承诺程度不明：可能、考虑、如果有空、要不。
- 事实与计划混合，主类分差不明显。
- 输入来自文件，无法确认是否应写入朋友档案。
- 高敏感关系风险：冲突、恋爱、家庭、财务、健康、隐私身份。

确认问题必须短而具体：

```text
这条更像是要创建一个行程提醒，还是只记录 Jason 最近准备面试的状态？
```

## 6. 自我检索边界

自我检索不是所有“我 + 情绪词”的集合。先区分三类：

| 字段 | 定义 | 默认处理 |
| --- | --- | --- |
| `episodic_self_state` | 一次性情绪或当日状态，例如“今天考试前有点焦虑”“和 Jason 吃饭有点尴尬” | 只能作为 `domain_object` / `proposal_kind=context_only` / `retention_policy=context_only`，不得作为 `workflow_primary` 或 `storage_targets`；只有用户确认长期保存价值、明显复盘、或反复模式证据时才升级 |
| `durable_self_pattern` | 反复出现的自我模式、价值观、习惯、恐惧、关系策略 | 默认可作为 `personal_reflection` 候选 |
| `relationship_boundary` | 用户在人际关系中的边界、禁区、风险偏好 | 默认可作为 `personal_reflection` + `relationship_memory/risk_boundary` 候选 |

只有 `durable_self_pattern` 和 `relationship_boundary` 默认具备长期自我检索价值。`episodic_self_state` 如果只是一次性情绪，必须说明为什么值得长期保存；否则只能作为来源上下文或临时状态候选，等待用户确认，不得写成长期 `personal_reflection`。

### 6.1 进入 `personal_reflection`

只有当“自我状态本身”是要被记住的内容时，才进入自我检索。

强信号不是关键词本身，而是结构条件：`affective_bearer=user` 且 `aboutness_target` 指向用户自己的状态、长期模式、价值判断或关系边界。以下表达只有在补语满足这个条件时才是强信号：

- 我发现自己……
- 我意识到……
- 我感觉自己……
- 我害怕/焦虑/后悔/压力很大……，且焦点是用户自身状态，不是提醒动机或外部风险
- 我总是……
- 我不敢……
- 我想成为……
- 我不太想/不愿意/边界是……

对比：

| 输入 | 结构判断 | 处理 |
| --- | --- | --- |
| 我怕 Jason 忘了材料 | `affective_bearer=user`, `aboutness_target=Jason/material risk` | 不是自我反思；担忧是提醒动机 |
| 我怕自己总是在关系里退缩 | `affective_bearer=user`, `aboutness_target=user-self-pattern` | `personal_reflection` |
| 我想下午和 Jason 吃饭但有点尴尬 | `primary_unit=meal plan`; `secondary_unit=episodic emotion` | 主卡仍是 `reminder_source/event`；尴尬可作为低优先级情绪上下文 |

示例：

| 输入 | 正确主类 | 说明 |
| --- | --- | --- |
| 今天准备考试时，我发现自己有点焦虑，想记一下这个状态 | `personal_reflection` review candidate | 只能进入待确认：用户需要选择“仅临时记录这次状态”还是“保存为长期自我理解” |
| 今天考试前有点焦虑 | `retention_policy=source_context_only` 或低优先级 `episodic_self_state` 候选 | 一次性情绪，未必长期沉淀 |
| 我好像总是怕麻烦 Alex，所以很多事情没说 | `personal_reflection` | 长期人际模式 |
| 我和 Alex 聊完发现自己太急了 | `personal_reflection` | 自我复盘，关系互动作证据 |
| 我后悔昨天没回复 Alex | `episodic_self_state` context + possible `relationship_memory` | 单次后悔默认不是长期反思；除非用户补充复盘、模式或保存意图 |
| 我不太想再和 Chris 单独吃饭 | `personal_reflection` | 边界/风险，不是日程 |

### 6.2 不应触发 `personal_reflection`

“我觉得/我怕/我担心/我想”不能单独触发自我反思。它们可能只是证据强度、提醒动机或不确定性。

| 输入 | 错误归类 | 正确处理 |
| --- | --- | --- |
| 我觉得 Alex 不吃香菜 | `personal_reflection` | `person_fact/dietary_preference_or_avoidance`, confidence 降低；只有明确说过敏才是 `dietary_allergy` |
| 我怕 Jason 忘了明天的材料 | `personal_reflection` | `reminder_source/follow_up`, reason: 担忧是提醒动机 |
| 我想给 May 买生日礼物 | `personal_reflection` | `relationship_opportunity/gift` gated workflow candidate；批准后事实/偏好仍写 `gift_signal` 或 `person_fact` |
| 我下周找 May 讨论项目 | `personal_reflection` | `reminder_source/event_or_follow_up` |

## 7. 行程安排边界

### 7.1 日程候选不等于可执行提醒

`reminder_source` 是上层记忆类型，不等于“可以立刻创建本地提醒”。分类层必须再区分：

| `schedule_execution_state` | 定义 | 示例 | 处理 |
| --- | --- | --- | --- |
| `draft_schedule_candidate` | 有待办/计划意图，但缺时间、承诺、触发条件或对象 | 找时间约 Alex 喝咖啡 | 进入整理台，要求用户确认 |
| `executable_reminder` | 动作、对象、提醒触发时间和通知策略都足够明确 | 明天 15:00 提醒我给 May 发材料 | 可生成可执行提醒草案，仍需用户批准 |
| `executable_schedule_item` | 事件时间完整，且用户明确选择 `calendar_only` 或 `no_notification` | 周三 15:00 和 Jason 开会，不用提醒 | 可生成无提醒日程草案，仍需用户批准 |
| `contextual_guard_candidate` | 有边界/禁忌内容，但缺可挂载事件 | 下次见 May 别提她前任 | 作为待确认边界/上下文提醒 |
| `anchored_contextual_guard` | 已匹配未来事件且可挂载 | 下周见 May 前别提她前任，已匹配下周会议 | 挂到对应未来事件，仍需用户批准 |
| `existing_item_mutation` | 取消、改期或修改已有事项 | 取消今晚和 Jason 的饭 | 必须匹配已有提醒；匹配失败则询问 |

模糊时间、缺失时间、条件计划只能进入 `draft_schedule_candidate`，不能伪装成已确认提醒。

没有时间但有用户动作时，仍然可以是日程候选：`找 May 聊项目`、`给 Jason 发消息` 应输出 `draft_schedule_candidate` + `time_expression_kind=missing_time`，询问何时提醒；不能因为缺时间就丢到朋友档案或自我反思。

可执行阈值：

| `schedule_subtype` | 升级到 `executable_reminder` 的最低条件 |
| --- | --- |
| `event` | 有用户参与或明确 actor，且 `start_at` 与通知策略分开解析；若要生成 reminder，必须有明确 `remind_at`、确认默认策略规范化出的 trigger，或 offset；若用户明确 `calendar_only/no_notification`，只能是 `executable_schedule_item` |
| `deadline` | 有 `due_at` 和 `remind_at` 或用户确认的 `notification_policy`；date-only `due_at` 单独存在时只能是 candidate |
| `task` | 有 `remind_at` 或用户确认的触发条件 |
| `follow_up` | 有对象、动作、渠道或动作方式，以及 `remind_at` 或确认触发条件 |
| `prep` | 有可匹配的目标 event/deadline 和提醒触发条件 |
| `recurring` | 有重复规则、时区，并且提醒策略已规范化成 `remind_time_or_null` 或 `next_trigger_at_or_null` |
| `anniversary_reminder` | 有纪念日事实、偏移规则和提醒触发时间 |
| `contextual_guard` | `anchor_status=anchored` 且有可匹配未来事件；否则不能 standalone 执行 |
| `cancel_existing` | 有唯一匹配的既有事项，且 `mutation_intent_confidence>=0.8` |
| `reschedule_existing` | 有唯一匹配的既有事项，且新时间槽足够完整；否则只能候选 |
| `update_existing` | 有唯一匹配的既有事项，且有明确 patch 语义 |

`recurring` 的“可执行”必须同时满足：有 `frequency`、`interval`、`anchor_date` 或等价起点、时区、重复日期规则，以及 `remind_time_or_null` 或 `next_trigger_at_or_null`。用户确认的默认提醒策略必须先规范化成这两个字段之一；不能只因为出现“每周五”就创建可执行提醒。

### 7.2 行程不是一个桶

当前实现可以继续投影为 `reminder_source`，但分类层必须保留 `schedule_subtype`，否则 UI 和提醒策略会混乱。

| `schedule_subtype` | 定义 | 示例 | 提醒策略 |
| --- | --- | --- | --- |
| `event` | 用户参与的时间块或约定活动 | 下午和 Jason 约饭、周三开会 | 需要 `start_at` 或明确时间窗口；模糊时间为 candidate |
| `deadline` | 截止前必须完成 | 周五前提交材料 | 需要 `due_at`，可另设 `remind_at` |
| `task` | 可完成的单步动作 | 给 May 发消息 | 可无精确时间，但需确认触发时间 |
| `follow_up` | 对人或项目状态的追问 | 明天问 Jason 面试怎么样 | 绑定对象、渠道和时间窗口 |
| `prep` | 为未来 event/deadline 做准备 | 面试前准备材料 | 必须依附目标事件或截止时间 |
| `recurring` | 周期事项 | 每周五问论文进度 | 需要重复规则；缺提醒时间则为 candidate |
| `anniversary_reminder` | 年度纪念提醒 | 每年 Alex 生日前一周提醒 | 先确认生日事实 |
| `cancel_existing` | 取消已有事项 | 取消今晚和 Jason 的饭 | 必须匹配已有提醒或待确认 |
| `reschedule_existing` | 改期已有事项 | 会议改到周五 | 必须匹配原事项 |
| `update_existing` | 修改已有事项细节 | 不用提醒我交材料了 | 必须匹配原事项 |

判定优先级：

1. `cancel_existing`、`reschedule_existing`、`update_existing` 优先于新建事项。
2. 用户参与的约定时间块是 `event`。
3. 有“前/截止/due/deadline”语义的是 `deadline`。
4. 单步完成动作是 `task`。
5. 对人或项目状态的追问是 `follow_up`。
6. 依附未来 event/deadline 的准备动作是 `prep`。
7. 周期表达进入 `recurring`，但没有触发时间时仍是 candidate。
8. 依附未来上下文的边界提醒进入 `contextual_guard`。

### 7.3 时间表达与解析上下文

不要只存一个“日期”。必须保留原文、解析上下文和解析结果。

| 字段 | 含义 |
| --- | --- |
| `raw_time_expression` | 原文时间，如“下周三”“下午”“周五前” |
| `time_role` | 该时间修饰什么：`event_start`, `reminder_trigger`, `deadline_due`, `recurrence_trigger`, `anchor_event`, `ambiguous` |
| `time_expression_kind` | `exact_datetime`, `absolute_date`, `relative_date`, `relative_window`, `fuzzy_window`, `event_relative`, `recurring_rule`, `missing_time` |
| `reference_date` | 解析相对时间所依据的日期 |
| `reference_datetime` | 解析和触发计算所依据的精确当前时间，含时区 |
| `timezone` | 例如 `Asia/Shanghai` |
| `locale` | 例如 `zh-CN` |
| `week_start` | 周起始日，避免“下周”歧义 |
| `time_precision` | `exact_minute`, `date_only`, `half_day_window`, `relative_window`, `unresolved` |
| `resolved_window` | 保留候选时间窗，例如“下午”可解析为本地偏好下午窗口但必须待确认 |
| `resolved_time` | 解析后的结构；无法解析则 null |
| `needs_slot_confirmation` | 是否因时间槽位缺失或歧义而不能执行 |
| `requires_user_approval` | 是否仍需用户批准写入；所有 `PendingUpdate` 均为 true |

时间类型：

| `time_expression_kind` | 示例 | 处理 |
| --- | --- | --- |
| `exact_datetime` | 2026-06-21 15:00 | 时间可解析；是否可执行取决于 `time_role` 和 `notification_policy` |
| `absolute_date` | 8 月 3 日、2026-06-21 | 日期明确，时间可能需确认 |
| `relative_date` | 明天、周五、下周三 | 需要 `reference_date`、timezone、week_start |
| `relative_window` | 生日前一周、面试前一天 | 需要目标事件或档案事实 |
| `fuzzy_window` | 下午、有空时、之后 | draft candidate，必须确认 |
| `event_relative` | 下次见 May 前、会议开始前 | contextual guard 或依附目标事件 |
| `recurring_rule` | 每周五、每月 3 号 | 需要完整重复规则和提醒触发时间 |
| `missing_time` | 找 May 聊项目 | draft candidate，询问时间 |

`absolute_date` 或 `relative_date` 如果只有日期，不能静默默认成早上、全天或晚上。`remind_at` 只能来自用户原文、用户已确认偏好、或本次确认问题。`下午` 这类半天窗口应保存为 `time_precision=half_day_window` + `resolved_window`，并保持 `needs_slot_confirmation=true`。

`notification_policy` 结构：

| 字段 | 含义 |
| --- | --- |
| `delivery_mode` | `reminder`, `calendar_only`, `no_notification`, `unspecified` |
| `policy_source` | user_explicit/user_preference/user_confirmed/system_default_disallowed |
| `trigger_at_or_null` | 绝对提醒时间 |
| `offset_or_null` | 相对事件/截止时间的偏移，例如 -P1D |
| `next_trigger_at_or_null` | recurring 或默认策略规范化后的下一次触发时间 |
| `timezone` | 时区 |
| `requires_confirmation` | 是否仍需用户确认 |
| `default_allowed` | 是否允许使用用户已确认默认策略；未确认默认策略必须为 false |

`system_default_disallowed` 表示当前没有可用提醒策略，不等于已确认的系统默认值。只有 `delivery_mode=reminder`，`policy_source` 为 `user_explicit`、`user_preference` 或 `user_confirmed`，且能得到 `trigger_at_or_null`、`next_trigger_at_or_null` 或清晰 offset，才可让 date-only deadline、window event 或 recurring 升级为 `executable_reminder`。

若用户明确选择 `delivery_mode=calendar_only` 或 `delivery_mode=no_notification`，不得创建本地提醒；只能生成 `executable_schedule_item` 或普通事实/日程候选。若用户只是陈述“周三 15:00 开会”，没有说“提醒我”或没有确认默认提醒策略，则不能自动把 `start_at` 复制到 `remind_at`。

所有提醒触发时间必须满足 `trigger_at_or_null > reference_datetime` 或 `next_trigger_at_or_null > reference_datetime`。若计算出的同日触发时间已经过去，必须按 recurrence 或用户确认策略推进到下一次未来触发；不得创建过期提醒。

例外：blocked candidate 可以保留已经过去的 `remind_at` 作为解析证据，但必须同时有 `confirmation_blockers` 包含 `past_trigger`，且 `schedule_execution_state` 不能是 `executable_reminder`。验证器应禁止“过去触发 + executable”，而不是禁止记录这次解析出的过去时间。

### 7.4 `start_at`、`end_at`、`due_at`、`remind_at` 的区别

| 字段 | 用途 | 示例 |
| --- | --- | --- |
| `start_at` | event 开始时间 | 周三 15:00 开会 |
| `end_at` | event 结束时间 | 16:00 结束 |
| `due_at` | deadline 截止时间 | 周五前提交材料 |
| `remind_at` | 何时提醒用户 | 提前一天提醒 |
| `deadline_relation` | deadline 截止边界语义 | `before_or_on`, `before_start_of_day`, `by_end_of_day`, `unknown` |

规则：

- `deadline` 必须优先填写 `due_at`，不能把截止日期误当 `start_at`。
- `event` 必须优先填写 `start_at`，没有明确开始时间时只是 candidate。
- `remind_at` 是提醒触发时间，不等于事件时间或截止时间。
- `deadline_relation` 必须保留“前/之前/当天截止/下班前”等边界语义；若未知，写 `unknown`，不得静默解释为当天 23:59。
- 未经用户确认，不要 silently default 到当天早上、全天或系统当前时间。
- date-only 输入可以创建 `draft_schedule_candidate`，但不得自动补全为 09:00、全天事件或晚上提醒。
- `due_at` 可以是结构化 date-only 对象，例如 `{ "date": "2026-06-19", "precision": "date_only" }`。不得为了凑 timestamp 自动转成 `23:59`、`09:00` 或全天事件。

### 7.5 承诺程度分级

| `commitment_level` | 示例 | 处理 |
| --- | --- | --- |
| `committed` | 我明天下午和 Jason 约饭 | 可生成行程待审；模糊时间仍需确认 |
| `intended` | 我打算下周找 May | 生成待确认行程 |
| `tentative` | 我可能下周找 May | 低 confidence，必须确认 |
| `conditional` | 如果有空就找 May | 不能伪装成已确认日程 |
| `suggested` | 要不找 Jason 吃饭？ | 建议/想法，待确认 |
| `past` | 上周和 Jason 吃饭了 | 不是提醒；可能是关系记忆 |
| `negative` | 我不想和 Chris 吃饭 | 不是日程；可能是边界/风险 |

### 7.6 行程肯定器

只有同时满足以下条件，才强进 `reminder_source`：

1. 有用户可执行动作、用户参与事件、用户需要准备/跟进/取消/改期。
2. 有未来、重复、截止、或需确认的时间语义。
3. 不是纯否定、纯回忆、纯朋友状态、纯自我反思。

### 7.7 行程否决器

以下不应直接生成新日程：

- `Jason 下周面试`：朋友状态，不是用户日程。
- `我害怕明天考试`：自我状态，不是待办。
- `May 想暑假旅行`：愿望/偏好，不是用户行程。
- `Jason 明天面试提醒我祝他好运`：用户动作是祝福提醒，不是把 Jason 的面试放进用户日程。
- `上周和 Jason 吃饭了`：过去事件，可是关系记忆。
- `我不想和 Chris 吃饭`：边界，不是安排。
- `有空再约 Alex`：只有关系意向，缺触发条件，不能生成可执行提醒。

### 7.8 上下文提醒

“下次见 May 别提她前任”这类内容不是 standalone reminder。

1. 若能匹配已有或候选未来事件，例如“下周和 May 见面”，生成 `anchored_contextual_guard` 并挂载该事件。
2. 若无法匹配未来事件，主卡偏 `person_fact/taboo_boundary` 或 `relationship_memory/risk_boundary`。
3. 可生成副卡 `contextual_guard_candidate`，询问是否要在下次见面前提醒。

`contextual_guard` payload 必须包含：

| 字段 | 含义 |
| --- | --- |
| `anchor_status` | `unmatched`, `ambiguous`, `anchored` |
| `anchor_event_id_or_null` | 已匹配未来事件 id；没有则 null |
| `anchor_match_score` | 0-100 |
| `candidate_anchors` | 候选未来事件列表，含 id、score、time_window |
| `target_person` | 关联人 |
| `taboo_topic_or_action` | 禁忌话题或要避免的行为 |
| `source_quote` | 原文证据 |
| `sensitivity` / `requires_discreet_review` | 是否需要低调展示 |
| `guard_condition` | 触发条件，例如 before_meeting/at_location/before_call |
| `guard_message` | 要提醒的边界内容 |
| `trigger_timing` | before/during/after/contextual |
| `expires_at_or_null` | 上下文守卫过期时间 |
| `scope` | only_this_person/this_context/general |
| `fallback_storage_target` | 无法挂载时写入 `person_fact/taboo_boundary` 或 `relationship_memory/risk_boundary` |
| `standalone_blocked_reason` | 无锚点时为什么不能独立执行 |

只有 `anchor_status=anchored`、`anchor_event_id_or_null` 非空且 `anchor_match_score>=80` 时，才可挂载到未来事件并进入 `anchored_contextual_guard`。`anchor_status=unmatched` 或 `ambiguous` 时只能是 `contextual_guard_candidate`，不得 standalone 调度。

### 7.9 重复事项规则

`recurring` 必须包含两类字段：可执行创建必填字段，以及可为空但必须显式说明的策略字段。

| 字段 | 可执行 recurring 必填 | 示例 |
| --- | --- | --- |
| `frequency` | true | weekly/monthly/yearly |
| `interval` | true | 1 |
| `anchor_date` | true | 2026-06-19 |
| `by_weekday` 或 `day_of_month` | true | Friday / day 3 |
| `remind_time_or_null` | true for executable unless `next_trigger_at_or_null` is present | 10:00 |
| `next_trigger_at_or_null` | true when default/user preference is used instead of explicit remind_time | 2026-06-26T10:00:00+08:00 |
| `timezone` | true | Asia/Shanghai |
| `end_condition_or_null` | explicit null allowed | until date / count / null |
| `skip_or_exception_policy` | explicit policy required | 跳过、顺延、询问 |
| `business_day_policy` | explicit policy or null | 周末/假期顺延、提前、照常 |
| `calendar_system` | explicit value | Gregorian / local calendar |
| `timezone_dst_policy` | explicit value or null | daylight saving 变化时如何处理 |

“每周五问 May 论文进度”如果没有具体提醒时间，应是 `draft_schedule_candidate`，需要确认触发时间。若用户有已确认默认策略，系统必须先把默认策略规范化为 `remind_time_or_null` 或 `next_trigger_at_or_null`，并在 `notification_policy.policy_source=user_preference` 中保留来源；否则不能是 `executable_reminder`。

### 7.10 取消、改期、更新匹配规则

`cancel_existing`、`reschedule_existing`、`update_existing` 必须匹配已有事项。

匹配字段至少包括：

- `target_person`
- `action`
- `time_window`
- `location`
- `source_entry_id`
- title similarity

0 个或多个候选时都不能新建提醒。0 个候选要问“要修改哪一项”；多个候选要让用户选择；只有一个高置信候选才生成 mutation 待审卡。

mutation 匹配评分：

| 字段 | 分值 | 说明 |
| --- | ---: | --- |
| `source_entry_id` 或 existing reminder id | 35 | 直接引用原事项时权重最高 |
| `time_window` | 20 | 今晚、周五、原定时间等 |
| `target_person` | 15 | Jason/May/团队等 |
| `action_or_title_similarity` | 15 | 约饭、交材料、会议等 |
| `location` | 5 | 地点一致 |
| `created_or_updated_recency` | 10 | 最近创建或最近提过 |

判定：

- 最高分 `>=80` 且领先第二名至少 15 分：可生成 `existing_item_mutation` 待审卡。
- 最高分 `60-79` 或领先不足 15 分：列候选，要求用户选择。
- 最高分 `<60`：不执行 mutation，不创建新提醒，只询问目标事项。

mutation 两阶段契约：

| 字段 | 值 | 含义 |
| --- | --- | --- |
| `match_status` | `unmatched`, `ambiguous`, `unique_high_confidence` | 当前是否已唯一匹配目标事项 |
| `can_approve_without_more_input` | true/false | 用户是否可以直接批准 mutation |
| `mutation_blockers` | structured blockers array | 未匹配、歧义、新时间缺失、scope 缺失等 |

只有 `match_status=unique_high_confidence` 且 `can_approve_without_more_input=true` 时，mutation 待审卡才可批准执行。否则仍可展示为 `existing_item_mutation` 候选，但主按钮必须是“选择目标事项/补充新时间/确认范围”，不是“批准执行”。

`cancel_scope` 枚举：

| `cancel_scope` | 必填补充字段 | 含义 |
| --- | --- | --- |
| `single_occurrence` | `occurrence_date` | 只取消某一次 recurring |
| `this_and_future` | `occurrence_date` | 从某次开始取消之后所有 recurrence |
| `entire_series` | recurrence id | 取消整个 recurring |
| `one_off_item` | target item id | 取消非 recurring 单次事项 |
| `unknown` | confirmation question | 用户没有说清取消范围 |

`mutation_match` payload 必须包含：

```json
{
  "mutation_type": "reschedule_existing",
  "target_entry_id": "reminder_123",
  "match_status": "unique_high_confidence",
  "can_approve_without_more_input": true,
  "operation_allowed": true,
  "mutation_intent_confidence": 0.92,
  "cancel_scope": null,
  "occurrence_date": null,
  "mutation_blockers": [],
  "old_slot_confidence": 0.88,
  "new_slot_completeness": "exact_datetime",
  "old_raw_time_expression": "今晚",
  "new_raw_time_expression": "明晚 18:00",
  "old_time_precision": "half_day_window",
  "new_time_precision": "exact_minute",
  "timezone": "Asia/Shanghai",
  "date_only_guard": "not_applicable",
  "match_score": 86,
  "matched_fields": ["target_person", "time_window", "action_or_title_similarity"],
  "old_values": {"start_at": "2026-06-19T18:00:00+08:00"},
  "new_values": {"start_at": "2026-06-20T18:00:00+08:00"},
  "patch_ops": [{"op": "replace", "path": "/start_at", "value": "2026-06-20T18:00:00+08:00"}],
  "ambiguous_candidates": []
}
```

不同 mutation 的额外要求：

| `mutation_type` | 必填 |
| --- | --- |
| `cancel_existing` | `target_entry_id`, `mutation_intent_confidence>=0.8`, `operation_allowed=true`, `cancel_scope != unknown` |
| `reschedule_existing` | `target_entry_id`, `old_slot_confidence>=0.7`, `new_values.start_at` 或用户确认后的 `new_values.resolved_window`；若该事项有提醒，还必须另有有效 `notification_policy` |
| `update_existing` | `target_entry_id`, `patch_fields`, `old_values`, `new_values`, `operation_allowed=true` |
| `disable_reminder` | `target_entry_id`, explicit reminder being disabled |

若 `operation_allowed=false`、`new_slot_completeness=unresolved`、或 patch 语义不明确，必须保留 `existing_item_mutation` 候选但不得执行。

| 匹配结果 | 处理 |
| --- | --- |
| 0 个匹配 | 不创建新的“取消提醒”；询问用户要取消哪一项 |
| 1 个高置信匹配 | 生成 existing-item mutation 待审卡 |
| 多个匹配 | 列出候选，要求用户选择 |
| 原事项时间缺失 | 不自动改期；要求确认原事项 |

### 7.11 日程类最低字段

每个日程类 `PendingUpdate` 至少提取：

| 字段 | 要求 |
| --- | --- |
| `schedule_subtype` | event/deadline/task/follow_up/prep/recurring/anniversary_reminder/contextual_guard/cancel_existing/reschedule_existing/update_existing |
| `schedule_execution_state` | draft_schedule_candidate/executable_reminder/executable_schedule_item/contextual_guard_candidate/anchored_contextual_guard/existing_item_mutation |
| `actor` | 谁执行，通常是用户 |
| `action` | 约饭、问、发、提交、取消、改期等 |
| `target_person` | 关联人，可为空 |
| `raw_time_expression` | 原文时间表达 |
| `time_role` | event_start/reminder_trigger/deadline_due/recurrence_trigger/anchor_event/ambiguous |
| `time_expression_kind` | exact_datetime/absolute_date/relative_date/relative_window/fuzzy_window/event_relative/recurring_rule/missing_time |
| `time_precision` | exact_minute/date_only/half_day_window/relative_window/unresolved |
| `resolved_window_or_null` | 模糊或半天窗口的候选范围 |
| `reference_date` | 相对时间解析基准 |
| `reference_datetime` | 触发计算基准；所有提醒触发必须晚于它 |
| `timezone` | 时区 |
| `resolved_time_or_null` | 可解析结构，否则 null |
| `start_at_or_null` | event 开始 |
| `end_at_or_null` | event 结束 |
| `due_at_or_null` | deadline 截止；可为 date-only object，不强制 timestamp |
| `deadline_relation_or_null` | before_or_on/before_start_of_day/by_end_of_day/unknown |
| `remind_at_or_null` | 提醒时间 |
| `commitment_level` | committed/intended/tentative/conditional/suggested/past/negative |
| `location_or_null` | 地点 |
| `recurrence_rule_or_null` | 周期事项的 frequency/interval/anchor_date/by_weekday/nth_weekday/remind_time_or_null/end_condition_or_null/skip_or_exception_policy/business_day_policy/calendar_system/timezone_dst_policy |
| `notification_policy_or_null` | delivery_mode/policy_source/trigger_at_or_null/offset_or_null/next_trigger_at_or_null/timezone/requires_confirmation/default_allowed |
| `mutation_match_or_null` | 修改已有事项时的 target_entry_id、match_status、can_approve_without_more_input、match_score、matched_fields、old_values、new_values、ambiguous_candidates、cancel_scope |
| `contextual_guard_or_null` | anchor_status/anchor_event_id_or_null/anchor_match_score/guard_condition/guard_message/standalone_blocked_reason |
| `needs_slot_confirmation` | 缺关键字段、低置信或 mutation 匹配不唯一时 true；字段完整则 false |
| `confirmation_blockers` | structured blockers array，驱动 UI 和测试 |
| `confirmation_reasons` | 兼容摘要；只能由 `confirmation_blockers[*].code` 派生 |
| `requires_user_approval` | 所有 `PendingUpdate` 均为 true，即使 `executable_reminder` 也必须经用户批准 |
| `reason_summary` | 为什么是行程，为什么不是反思/朋友事实 |

缺少时间不代表不能进日程，但不能伪装成已确认提醒。

`confirmation_blockers` 结构：

```json
[
  {
    "code": "notification_policy_missing",
    "field": "notification_policy",
    "required_for": "executable_reminder",
    "observed_value": {
      "delivery_mode": "reminder",
      "trigger_at_or_null": null,
      "offset_or_null": null
    },
    "question": "你希望我什么时候提醒你？"
  }
]
```

必备 blocker code：`time_slot`, `target_item`, `recurrence_policy`, `reminder_strategy`, `notification_policy_missing`, `anchor_event_missing`, `mutation_match_ambiguous`, `mutation_match_unmatched`, `cancel_scope_missing`, `date_only_due_without_reminder`, `deadline_relation_unknown`, `past_trigger`, `classification_ambiguity`, `low_confidence`。每个 `needs_slot_confirmation=true` 的行程样本至少要有一个 `confirmation_blockers` 元素。

## 8. 朋友档案与人脉资产

### 8.1 朋友档案不是静态通讯录

朋友档案分两条通道：普通朋友事实通道和人脉资产增强通道。不是每条朋友事实都要被商业化、机会化或排序成关系动作。

普通朋友事实通道：

- 适用于饮食、兴趣、生日、学校、城市、普通沟通偏好等低风险资料。
- 输出 `asset_dimension=none`、`business_relevance=null`、`recommended_next_action_or_null=null`。
- 不生成 `relationship_opportunity`，不进入机会评分，不因“有价值”而提高提醒优先级。
- 只服务 profile completeness 和未来检索，不暗示用户应该经营、索取或触达。

人脉资产增强通道只适用于确实含有资源、需求、影响力、合作、引荐、帮助历史、风险边界或互惠价值的事实。可识别的资产目标包括：

- `profile_completeness`：补全稳定资料。
- `relationship_signal`：解释关系变化。
- `relationship_opportunity`：发现可跟进动作。
- `risk_reduction`：避免踩雷、冲突、隐私冒犯。
- `resource_intelligence`：沉淀资源、能力、影响领域。
- `reciprocity_memory`：记住帮过谁、谁帮过我、欠人情。

### 8.2 资产维度

不要求立即新增数据库字段；短期可存入现有 `PersonProfileCategory`、`PendingUpdate` envelope 或 review explanation。长期可考虑专门结构。

| 资产维度 | 含义 | 可映射到现有类别 |
| --- | --- | --- |
| `resources` | 对方掌握的资源、渠道、技能、信息 | `career`, `education`, `friend_network`, `ai_inference` |
| `none` | 普通朋友事实，无商业/关系动作价值 | `interests`, `dietary`, `identity`, `anniversaries`, `communication_preference` |
| `needs` | 对方近期需要什么帮助 | `current_state`, `career`, `education` |
| `influence_area` | 影响圈层、专业领域、组织位置 | `career`, `friend_network`, `identity` |
| `business_role` | 对方在合作/组织/项目中的角色 | `career`, `identity` |
| `decision_power` | 是否能影响资源、机会、决策 | `career`, `friend_network`, `ai_inference` |
| `access_to_network` | 能连接到哪些人或圈层 | `friend_network`, `relationship` |
| `collaboration_fit` | 与用户合作的适配点 | `career`, `education`, `interests` |
| `current_ask` | 对方现在可能需要用户帮什么 | `current_state`, `career` |
| `possible_offer` | 用户能主动提供什么帮助 | `relationship`, `career`, `education` |
| `collaboration_context` | 合作项目、共同任务、角色分工 | `relationship`, `career`, `education` |
| `help_history` | 帮助、感谢、人情往来 | `relationship`, `life_events` |
| `communication_cadence` | 适合多久联系一次、偏好渠道 | `communication_preference` |
| `risk_boundary` | 禁区、敏感话题、单独见面边界 | `taboo_boundary` |
| `portfolio_signal` | 圈层/组合层信号：关键连接人、弱关系池、资源集中风险、声誉风险、互惠余额、沉睡关系节奏、关系组合缺口 | envelope/review metadata |
| `last_seen_at` | 信息观察时间 | envelope/review metadata |
| `expires_at` | 短期状态的过期时间 | envelope/review metadata |
| `source` | 谁说的、来自哪份文件 | `source_context` |

### 8.3 朋友事实判定

进入 `person_fact`：

- 稳定偏好：喜欢、不喜欢、爱吃、不吃。
- 身份资料：学校、专业、公司、城市、家乡。
- 联系方式：微信、电话、邮箱、LinkedIn。
- 沟通边界：不喜欢突然电话、提前约更舒服。
- 当前状态：最近准备面试、这学期在做项目。
- 资源/需求：能介绍导师、在找实习、需要简历反馈。

不要误判：

- `Jason 最近准备面试，我明天问问他` 主卡是跟进，朋友状态为副卡。
- `May 和 Alex 最近一起做项目` 是关系记忆，不是 May 的单人事实。
- `我觉得 Alex 不吃香菜` 是低置信朋友事实，不是自我反思。

普通事实负样本：

| 输入 | 正确处理 | 禁止动作 |
| --- | --- | --- |
| Alex 喜欢薯片，不吃香菜 | `person_fact`, `asset_dimension=none`, `business_relevance=null` | 不生成机会、不排序为触达建议 |
| May 喜欢提前约时间 | `person_fact/communication_preference`, `asset_dimension=none` 或低风险 `risk_reduction` context | 不自动创建提醒 |
| Jason 的生日是 8 月 3 日 | `person_fact/anniversaries`, optional reminder confirmation | 不自动购买礼物、不默认年度提醒 |
| Chris 在上海 | `person_fact/location`, `asset_dimension=none` | 不自动推荐见面 |

### 8.4 人脉资产最低输出协议

凡是带有资源、需求、影响力、合作、引荐、帮助历史或边界价值的 `person_fact`，都必须输出以下字段；证据不足时只能做低置信档案候选或 blocked confirmation card，不能升级成高优先级机会。普通朋友事实可以只输出 `asset_dimension=none` 和 `business_relevance=null`。

| 字段 | 要求 |
| --- | --- |
| `asset_dimension` | none/resources/needs/influence_area/business_role/decision_power/access_to_network/collaboration_fit/current_ask/possible_offer/help_history/risk_boundary |
| `business_relevance` | 为什么这条信息对用户的人际经营或资源整合有价值；没有则为 null |
| `evidence_quote` | 直接证据片段 |
| `confidence` | 0-1，低证据必须低 confidence |
| `observed_at` | 信息观察时间 |
| `expires_at_or_null` | 当前状态、需求、角色、决策权、网络入口必须设置过期或刷新时间 |
| `recommended_next_action_or_null` | 只有存在明确可做动作时填写 |
| `give_first_offer_or_null` | 用户可以先提供什么帮助 |
| `risk_boundary_or_null` | 隐私、关系阶段、利益冲突、冒犯风险 |

易过期资产：

- `current_state`
- `needs`
- `decision_power`
- `business_role`
- `access_to_network`

过期或来源陈旧的信息不能作为高置信机会依据，只能提示“建议刷新确认”。

整理台与 People 页落点：

| 场景 | 整理台处理 | People 页处理 |
| --- | --- | --- |
| 高置信稳定事实 | 展示证据、类别、置信度，允许批准/编辑/拒绝 | 批准后进入对应档案类别 |
| 低置信资源/需求 | 默认折叠为“待确认资产”，要求用户编辑证据或置信度 | 未确认前不写长期档案，只保留 source context |
| 已过期 current_state/needs/access | 标记“可能已过期”，建议刷新确认 | 折叠到历史状态，不参与高优先级机会 |
| 高风险边界/敏感关系 | `requires_discreet_review=true`，不在普通卡片标题暴露细节 | 仅在用户确认后写入风险/边界类信息 |
| 关系机会 | 先显示事实证据，再显示建议动作；批准事实不等于批准动作 | 事实和机会分开沉淀，机会完成后才写 outcome |

机会卡必须提供的用户操作：

| 操作 | 效果 |
| --- | --- |
| `archive_fact_only` | 只保存事实或关系记忆，不接受机会动作 |
| `accept_action` | 接受建议动作，但仍可编辑时间、渠道、文案目的 |
| `edit_consent_strategy` | 修改 ask_target_first/ask_intermediary_first/consent_scope |
| `edit_relationship_stage` | 用户纠正关系阶段和置信度 |
| `edit_network_path` | 用户纠正中间人、目标资源和 trust_basis |
| `mark_unknown` | 将 AI 推断的 stage/path/resource 改为 unknown/unavailable |
| `mark_not_actionable` | 保留事实但禁止当前机会动作 |
| `split_merge_proposals` | 拆分或合并同一原文产生的事实/机会/提醒 |
| `reject_with_reason` | 拒绝并记录原因，用于未来抑制 |
| `edit_priority_or_reason` | 用户纠正分数或重要性理由 |
| `convert_to_reminder` | 只有通过日程协议后才转提醒 |
| `close_opportunity` | 关闭机会并记录原因 |
| `mark_completed` | 标记已完成，进入 outcome 记录 |
| `record_outcome` | 记录 accepted/declined/no_response 等结果 |
| `refresh_asset` | 请求刷新过期资源、需求或 network_path |

用户纠错后的状态契约：

| 用户操作 | 成为 override 的字段 | 必须重算/重评估 | 必须失效的旧建议 |
| --- | --- | --- | --- |
| `edit_relationship_stage` | `relationship_stage`, `relationship_stage_confidence=1.0`, `stage_evidence_quote=user_override` | blocker、cap、`priority_score_audit`、推荐动作强度 | 依赖旧 stage 的 ask/intro/referral 建议 |
| `edit_network_path` | `network_path.edges`, `trust_basis`, `network_path_status`, `path_confidence` | consent 策略、path blocker、score cap | 依赖旧 path 的引荐动作 |
| `edit_consent_strategy` | `party_consents`, `consent_scope`, `allowed_information`, `consent_expires_at_or_null` | consent blocker、`safe_to_offer_intro`、`do_not_intro_without_context` | 旧同意范围外的动作模板 |
| `mark_unknown` | stage/path/resource 对应字段改为 unknown/unavailable | blocker 重新评估，`priority_score=null` if ask/intro/referral | 所有高压索取动作 |
| `mark_not_actionable` | `opportunity_lifecycle_state=closed`, `close_reason=not_actionable` | suppression rule | 同一 source/person/type 的重复机会 |
| `edit_priority_or_reason` | 用户理由进入 `manual_priority_note`；不直接覆盖事实证据 | score explanation 重新生成，保留 user override 标记 | 与用户理由矛盾的排序解释 |

任何 override 都必须写入 audit trail：`overridden_fields`、`overridden_by=user`、`overridden_at`、`previous_values`、`recalculated_fields`。重新计算后，若 blocker 仍命中，不能因为用户接受了卡片就放行到 `accept_action` 或 `convert_to_reminder`。

## 9. 关系记忆与关系经营机会

### 9.1 关系记忆必须输出关系信号

`relationship_memory` 不只是“谁和谁互动”。应提取：

| 字段 | 含义 |
| --- | --- |
| `participants` | 参与者 |
| `event_or_context` | 场景：项目、饭局、介绍、冲突、支持 |
| `relationship_signal` | 变熟、疏远、合作、欠人情、共同朋友 |
| `sentiment_or_tone` | 正向、中性、紧张、风险 |
| `network_path` | 谁能连接谁、连接到什么资源、是否需要中间人、是否已有信任基础 |
| `evidence_quote` | 原文证据 |
| `suggested_follow_up` | 可选跟进，不直接执行 |
| `risk` | 边界、隐私、冲突、利益风险 |

关系信号可以辅助关系图，但不能直接修改 manual closeness level。

关系阶段会影响建议强度：

| `relationship_stage` | 可建议动作 |
| --- | --- |
| `unknown` | 只允许低风险确认问题；不得推断关系强度 |
| `new_contact` | 轻量问候、感谢、确认偏好；避免索取 |
| `warm_acquaintance` | 低成本互助、信息交换、谨慎引荐 |
| `active_friend` | 更自然的跟进、支持、邀约 |
| `collaborator` | 项目推进、会议、材料、明确分工 |
| `mentor_or_senior` | 尊重节奏，偏正式渠道，明确请求边界 |
| `dormant_tie` | 先恢复联系，不直接请求资源 |
| `sensitive_tie` | 默认保守，不主动建议高压动作 |

`relationship_stage` 推断协议：

| 信号 | 用途 |
| --- | --- |
| 用户手动标注 | 最高优先级，覆盖 AI 推断 |
| 最近互动时间 | 判断 active/dormant |
| 互动频率和渠道 | 判断 new/warm/active |
| help_history/reciprocity_memory | 判断是否具备请求或感谢基础 |
| collaboration_context | 判断 collaborator |
| mentor/senior/authority 线索 | 判断 mentor_or_senior |
| conflict/risk_boundary/sensitive topic | 判断 sensitive_tie |

每次推断必须输出 `relationship_stage_confidence` 和 `stage_evidence_quote`。置信度低于 0.7 时，不得生成高压请求，只能建议确认或低打扰动作。用户在整理台改阶段后，该手动选择优先于后续 AI 推断。

`dormant_tie` 默认阈值：最近 90 天无互动且过去互动频率低于每月 1 次，或最近 180 天无任何正向互动证据。若只有“最近不回消息”但没有历史互动基线，输出 `relationship_stage=unknown` + `risk_note`，不得直接定为 `dormant_tie`。

证据不足规则：

- 缺少互动证据、用户手动标注或明确来源时，`relationship_stage=unknown`、`relationship_stage_confidence<=0.49`。
- 不得凭“认识某人”编造 `warm_acquaintance`、`trust_basis` 或 `path_confidence`。
- `stage_evidence_quote` 为空时，阶段只能是 `unknown`。
- `network_path` 缺任何关键节点时，输出 `network_path_status=unavailable`，不能生成引荐或索取动作。
- `network_path` 每条连接边都必须有 edge-level evidence；缺任一边证据时最多 `partial`，不得进入可引荐动作。

`network_path` 最低字段：

| 字段 | 含义 |
| --- | --- |
| `network_path_status` | available/unavailable/partial |
| `from_person` | 用户可接触的人 |
| `via_person_or_group` | 中间人或组织 |
| `to_person_or_resource` | 目标人、资源或圈层 |
| `trust_basis` | 连接依据：合作、帮忙、同学、导师、朋友等 |
| `edges` | 每条边的 from/to、evidence_quote、confidence、consent_status |
| `consent_required` | 是否需要同意 |
| `path_confidence` | 0-1 |

`edges` 例子：

```json
[
  {
    "from": "user",
    "to": "Jason",
    "evidence_quote": null,
    "confidence": 0.0,
    "consent_status": "not_asked"
  },
  {
    "from": "Jason",
    "to": "investor",
    "evidence_quote": "Jason 认识一个投资人",
    "confidence": 0.7,
    "consent_status": "not_asked"
  }
]
```

`path_confidence` 不得高于最低边置信度。任一边 `evidence_quote=null` 时，`network_path_status` 只能是 `partial` 或 `unavailable`。

### 9.2 关系经营机会

很多“礼物线索”本质是关系经营触点，不应只限于买礼物。

canonical `opportunity_type`：

| `opportunity_type` | 含义 | 常见投影 |
| --- | --- | --- |
| `gift` | 礼物、生日、纪念日、偏好、愿望清单 | `gift_signal` |
| `congratulate` | 面试、offer、比赛、发表、毕业 | `relationship_memory` 或 `reminder_source` |
| `comfort` | 考试失利、生病、压力、家庭事件 | `relationship_memory` 或 `reminder_source` |
| `thanks` | 对方帮忙、引荐、提供资源 | `relationship_memory/help_history` |
| `intro` | 帮对方或双方建立连接 | `relationship_memory/network_path` |
| `follow_up` | 材料、会议、进度、合作机会 | `reminder_source` |
| `risk_reduction` | 避开禁忌话题、提前约、选择合适渠道 | `person_fact/taboo_boundary` 或 `relationship_memory/risk_boundary` |
| `referral_request` | 用户请求资源、内推、介绍 | `relationship_opportunity` workflow only |

兼容映射：旧版安慰/支持类标签必须归一到 `comfort`；旧版索取引荐类标签必须归一到 `referral_request`；旧版触点标签若出现，只能作为 `opportunity_type` 的别名，不作为第二套枚举。

建议增加工作流级辅助提案 `relationship_opportunity/<opportunity_type>`，但它必须满足显式行动意图门槛。无论短期 UI 或旧 schema 如何投影到 `gift_signal`、`reminder_source`、`relationship_memory`，envelope 只有在用户表达 ask/referral/intro/follow-up/reminder/“我可以/我想/我要处理”等行动意图时，才允许保留 `workflow_primary` 或 `secondary_workflows` 中的 `relationship_opportunity/<type>`。它不是 confirmed 存储目标。

无行动意图硬门槛：

| 输入只有事实/状态 | 允许结果 | 禁止结果 |
| --- | --- | --- |
| 生日、偏好、愿望、最近压力、面试、帮过我 | `person_fact` 或 `relationship_memory`；可附 `latent_relationship_affordance=<gift/congratulate/comfort/thanks>` 作为解释 | `relationship_opportunity` lifecycle、`blocked_opportunity_confirmation`、`priority_score`、自动触达建议 |
| 用户补充“提醒我/我想/我可以/帮我准备/下次见面前” | 可进入 `relationship_opportunity/<type>` 或 schedule candidate | 不得跳过 consent/give-first/time slot/notification policy |
| 资源事实“认识某人/有渠道/在某公司” | `asset_fact_card` / `person_fact/resources` | ask/referral/intro lifecycle，除非用户明确提出目标 |

默认策略是 give-first：系统推荐动作时优先识别用户能为对方提供什么帮助，再识别用户可以请求什么资源。除非用户明确表达请求意图，不要把关系经营机会包装成索取型 CRM。

give-first 硬门槛：

| 场景 | 允许动作 |
| --- | --- |
| 用户没有明确请求，只有“对方有资源” | 只记录 `person_fact/resources`，不生成 ask |
| `relationship_stage=new_contact/dormant_tie` 且无互惠基础 | 只建议低打扰问候或价值提供，不建议索取 |
| 缺少 `give_first_offer` 或互惠基础且动作为 `ask/referral_request/intro` | blocker：`priority_score=null`，禁止生成 ask/referral/intro 动作；只能生成“补充上下文/先提供价值”的确认卡 |
| 涉及第三方联系方式或敏感背景 | 必须先获得同意；不能建议直接转发 |
| 用户明确“我想找 Jason 要内推” | 可生成 request 机会，但必须附带 give-first framing、关系阶段、风险和 fallback |

关系实践价值只影响 `workflow_primary`、排序和建议语气，不能改变事实分类本身。`Jason 认识投资人` 仍先是 `person_fact/resources`；是否产生引荐机会取决于用户意图、关系阶段、同意边界和时效。

最低字段：

| 字段 | 含义 |
| --- | --- |
| `target_person` | 对象 |
| `opportunity_type` | gift/congratulate/comfort/thanks/intro/follow_up/risk_reduction/referral_request |
| `recommended_channel` | 微信、当面、邮件、电话、不建议主动 |
| `time_window` | 何时适合 |
| `relationship_value` | 拆分为 `trust_building`, `reciprocity_repair`, `strategic_connection`, `emotional_support_value`, `risk_prevention`, `collaboration_progress` |
| `priority_score` | 0-100；由 urgency、relationship_value、strategic_value、reciprocity_value、risk_level、time_sensitivity 决定 |
| `risk_note` | 为什么要谨慎 |
| `relationship_stage` | unknown/new_contact/warm_acquaintance/active_friend/collaborator/mentor_or_senior/dormant_tie/sensitive_tie |
| `action_type` | message/meet/intro/thank/congratulate/comfort/follow_up/ask/referral/avoid_topic |
| `suggested_message_intent` | 建议消息目的，不直接替用户发送 |
| `channel` | 微信/邮件/电话/当面/不建议主动 |
| `timing` | 现在、某日期前、某事件后、等待确认 |
| `expected_outcome` | 希望推进到什么结果 |
| `fallback_if_no_response` | 对方无回应时如何收束 |
| `needs_slot_confirmation` | 是否因缺字段或歧义而需要槽位确认 |

触点动作模板分型：

| `opportunity_type` | 最低证据 | 推荐渠道 | 时机窗口 | 主要风险 | 完成后沉淀 |
| --- | --- | --- | --- | --- | --- |
| `gift` | 对方愿望/偏好/生日/禁忌的原文证据 | 当面/微信，不默认购买 | 生日/节日前或用户确认时间 | 太贵、太亲密、踩禁忌 | gift outcome、偏好修正 |
| `congratulate` | 面试、offer、比赛、发表、毕业等事件 | 微信/当面 | 事件当天或结果公布后 24-48 小时 | 太功利、时机过早 | positive touchpoint |
| `comfort` | 生病、压力、失利等状态 | 低打扰微信 | 近期，避免深夜或对方忙时 | 过度打探隐私 | support outcome、边界 |
| `thanks` | 对方帮助、引荐、资源提供 | 当面/微信/邮件 | 帮助后 1-7 天 | 显得交易化 | reciprocity_memory |
| `intro` | 双方需求匹配、同意路径明确 | 先分别确认，再建群/邮件 | 双方同意后 | 暴露联系方式、错配 | network_path outcome |
| `follow_up` | 对方状态或共同项目有后续动作 | 微信/邮件/项目渠道 | deadline 或约定窗口前 | 过度催促 | progress/outcome |
| `risk_reduction` | 禁忌、边界、冲突、敏感偏好 | 通常不主动发消息 | 相关上下文出现前 | 暴露敏感内容 | risk_boundary refinement |

### 9.3 机会优先级

`relationship_opportunity` 必须给出可复算的 `priority_score`，用于决定整理台排序，但不能绕过用户确认。若真实机会卡命中 blocker，必须输出 `priority_score=null` 和 `priority_score_audit.blockers`，不得用低分伪装成可执行机会。

`priority_score_audit.blockers` 只属于实际 `relationship_opportunity` confirmation/actionable card。纯资源 `asset_fact_card`、普通 `person_fact`、`gift_signal/touchpoint`、`latent_relationship_affordance` 禁止携带该结构；这些对象只能用 `why_no_action`、`action_gates_if_user_requests_*` 或普通解释说明为什么暂不行动。

| 评分因子 | 高分条件 |
| --- | --- |
| `urgency` | 有明确时间窗口、deadline、生日、面试、病假、入职等 |
| `trust_building` | 能增强信任、兑现承诺、表达感谢 |
| `strategic_value` | 连接关键资源、导师、校友、项目、实习或合作机会 |
| `reciprocity_value` | 还人情、补偿帮助、维护互惠 |
| `risk_level` | 风险越高越需要谨慎，不简单抬高优先级；高风险要求确认 |
| `time_sensitivity` | 错过窗口后价值明显降低 |

优先级解释必须说明“为什么现在处理”，而不只是说“这很重要”。

可复现公式：

```text
base_score =
  urgency(0-20)
  + trust_building(0-15)
  + strategic_value(0-20)
  + reciprocity_value(0-15)
  + time_sensitivity(0-15)
  + user_stated_intent(0-10)
  + give_first_fit(0-5)
  - risk_penalty(0-30)
```

因子刻度：

| 因子 | 确定分值桶 |
| --- | --- |
| `urgency` | no_window=0, month_window=4, week_window=8, three_day_window=12, next_day=16, same_day_or_deadline=20 |
| `trust_building` | none=0, light_touch=5, meaningful_support=10, promise_or_repair=15 |
| `strategic_value` | none=0, weak_info=5, relevant_resource=10, strong_resource=15, critical_resource_with_user_goal=20 |
| `reciprocity_value` | none=0, minor_thanks=5, clear_help_history=10, debt_or_repair=15 |
| `time_sensitivity` | none=0, month_decay=3, week_decay=6, three_day_decay=10, expires_immediately=15 |
| `user_stated_intent` | none=0, implied=5, explicit=10 |
| `give_first_fit` | none=0, generic_offer=2, concrete_offer=5 |
| `risk_penalty` | none=0, mild_intrusion=5, weak_tie_request=10, consent_or_privacy_risk=20, sensitive_or_high_pressure=30 |

评分顺序：

1. 先检查 blocker；命中 blocker 时不生成 actionable opportunity card，`priority_score=null`。
2. 计算 `raw_score`，范围允许为负。
3. 应用所有 cap，取最小上限。
4. 若没有 cap，`min_cap=100`；否则 `min_cap` 为所有 cap 的最小值。
5. `final_score = max(0, min(100, min(raw_score, min_cap)))`。
6. 四舍五入到整数。
7. `priority_score` 必须等于 `final_score`。

上限规则先于最终分：

| 条件 | 分数上限 |
| --- | ---: |
| 缺少 `evidence_quote` 或 `confidence < 0.5` | 39 |
| `relationship_stage_confidence < 0.7` | 59 |
| 需要同意但未输出同意策略 | 59 |
| 资源/需求已过期或未设置 `expires_at` | 49 |
| 弱关系或沉睡关系上的索取动作，且已有 `give_first_offer` 但互惠基础弱 | 59 |
| 涉及健康、财务、身份、恋爱、家庭冲突等敏感背景且未获确认 | 39 |

阻断项：

- 需要暴露第三方联系方式但没有同意：不生成 actionable opportunity card。
- 请求动作会绕过中间人或破坏信任：只保留风险提示。
- 证据来自截图/文件但来源未确认：只生成 source-context 候选。
- 对方明确不愿被打扰或关系处于 `sensitive_tie`：不生成主动触达机会，除非用户明确要求。
- ask/referral/intro 缺少 give-first 或互惠基础：不生成索取动作，只生成确认卡，`priority_score=null`。

blocker 卡片类型：

| 类型 | 允许出现的 workflow | `priority_score` | 允许用户动作 | 禁止动作 |
| --- | --- | ---: | --- | --- |
| `asset_fact_card` | `person_fact/resources` 等事实卡 | null | 批准事实、编辑事实、拒绝 | accept_action、convert_to_reminder |
| `blocked_opportunity_confirmation` | `relationship_opportunity/<type>` confirmation only | null | 补充关系阶段、补充 give-first、编辑 consent、archive_fact_only、mark_not_actionable | 生成 ask/intro/referral 文案、scheduled |
| `actionable_opportunity` | `relationship_opportunity/<type>` | 0-100 | accept_action、edit、convert_to_reminder、close | 跳过用户批准 |

因此，“不生成机会卡”在本方案中严格指“不生成 actionable opportunity card”。为了让用户补信息，可以生成 `blocked_opportunity_confirmation`，但标题、排序和按钮必须表现为“补充上下文/确认边界”，不能表现为“建议你去索取资源”。

硬阈值：

| `priority_score` | 处理 |
| ---: | --- |
| `>=80` | 整理台高优先级，但仍必须用户确认；必须有明确时间窗口、信任/互惠基础或资源价值之一 |
| `60-79` | 普通机会，可与关系摘要合并 |
| `40-59` | 只作为上下文，不主动提醒 |
| `<40` | 不生成 actionable opportunity card，除非用户明确要求 |

高分不能只因为“对方有资源”。没有关系阶段、同意路径、用户明确需求或可提供价值时，资源事实只能进档案，不应强推机会。

`priority_score_audit` 固定结构：

```json
{
  "scoring_version": "relationship_opportunity_v1",
  "blockers": [
    {
      "code": "missing_give_first_or_reciprocity",
      "triggered": true,
      "evidence_quote": null,
      "explanation": "用户想请求资源，但没有说明能先提供什么价值或已有互惠基础"
    }
  ],
  "factors": [
    {
      "name": "strategic_value",
      "bucket": "relevant_resource",
      "score": 10,
      "evidence_quote": "Jason 认识一个投资人",
      "unit_id": "u1"
    }
  ],
  "caps": [
    {
      "code": "relationship_stage_confidence_below_threshold",
      "cap_value": 59,
      "triggered": true,
      "evidence_quote": null
    }
  ],
  "raw_score": null,
  "min_cap": null,
  "final_score": null,
  "priority_score": null
}
```

如果 `blockers[*].triggered=true`，`raw_score`、`min_cap`、`final_score` 和 `priority_score` 都必须为 null。没有 blocker 时，所有 factor 必须有 bucket、score 和 evidence_quote 或 explicit null reason；所有 cap 必须有 `cap_value`。

### 9.4 引荐与同意边界

涉及第三方引荐、联系方式、资源请求、截图来源、敏感背景、财务/健康/身份信息、弱关系请求、多人互相介绍时，必须显式输出同意策略：

| 字段 | 含义 |
| --- | --- |
| `requires_consent` | 是否需要先获得一方或多方同意 |
| `fact_storage_external_consent_required` | 用户把事实存进自己的私密档案时，是否需要外部当事人同意；默认 `false`，但仍需要用户批准 PendingUpdate |
| `action_consent_required` | 引荐、转发联系方式、代承诺、联系第三方或分享背景信息前是否需要外部同意 |
| `ask_target_first` | 是否先问被介绍对象 |
| `ask_intermediary_first` | 是否先问中间人 |
| `safe_to_offer_intro` | 当前证据是否足以安全提出引荐 |
| `do_not_intro_without_context` | 是否禁止无上下文转发联系方式 |
| `consent_scope` | 允许分享的信息范围：name/background/contact/project_context 等 |
| `allowed_information` | 具体可分享字段列表 |
| `consent_source` | user_confirmed/target_confirmed/intermediary_confirmed/file_claimed/unknown |
| `consent_observed_at` | 同意观察时间 |
| `consent_expires_at_or_null` | 同意过期时间 |
| `consent_withdrawn` | 是否撤回 |
| `party_consents` | 多方分别同意状态 |

默认规则：不要默认暴露第三方联系方式；不要替用户承诺引荐；不要把“认识某人”直接等同于“可以介绍某人”。把事实存入用户自己的私密朋友档案，只需要用户在整理台批准，不表示已获得 Jason、投资人或第三方对后续引荐/联系方式分享的同意。

同意拆分硬规则：

- `fact_storage_external_consent_required=false`：适用于用户私密档案里的普通朋友事实、资源事实、历史互动和关系边证据；仍需用户批准写入，但不要求外部当事人先同意。
- `action_consent_required=true`：只适用于 intro/referral/contact sharing/代表他人承诺/转发截图或敏感背景等行动。
- `network_path.edges[*].consent_status=not_asked` 只说明行动路径还没有同意，不得反推“事实不能存”。
- `requires_consent` 若为兼容旧字段，只能映射行动同意，不得用于事实存档。

缺少 `consent_scope` 或 `allowed_information` 时，即使 `requires_consent=true`，也不能生成 intro/referral 执行动作，只能生成“先确认可分享范围”的确认卡。

同意决策矩阵：

| 场景 | 必须先问谁 | 可进入 intro/referral draft 的最低条件 | 否则处理 |
| --- | --- | --- | --- |
| May 让我介绍她给 Alex | 先问 Alex；May 的同意只覆盖 May | `party_consents.May=confirmed`, `party_consents.Alex=confirmed`, `consent_scope` 明确 | 只存 May 的需求和 intro candidate |
| 用户想问 Jason 要投资人介绍 | 先问 Jason；Jason 同意后再确认可分享范围 | `party_consents.Jason=confirmed`, `allowed_information` 明确 | referral_request confirmation card |
| 转发第三方联系方式 | 先问联系方式所有者 | explicit contact-sharing consent | 禁止转发，存风险边界 |
| 多方互相介绍 | 每一方分别同意 | 所有 party consent confirmed | 不建群/不发邮件，只保留候选 |
| 来源来自截图/文件 | 先确认来源可用 | source confirmed + consent strategy | source context only |

`party_consents` 状态：`not_asked`, `asked_pending`, `confirmed`, `declined`, `expired`, `withdrawn`。`declined` 和 `withdrawn` 是 blocker。

执行前二次检查：

| 进入状态/操作 | 必须重新检查 | 失败时 |
| --- | --- | --- |
| `accept_action` | blocker、`party_consents`、`allowed_information`、`give_first_offer_or_null` 或互惠基础、`relationship_stage_confidence` | 回到 `blocked_opportunity_confirmation` |
| `convert_to_reminder` | 日程协议、时间槽、notification_policy、动作是否仍被 consent/give-first 允许 | 只生成待确认 schedule candidate 或拒绝转换 |
| `scheduled` | consent 未过期、提醒内容不泄露第三方隐私、network_path 仍 available | 转 `stale` 或 `blocked_pending_context` |
| 生成 ask/intro/referral 文案 | `safe_to_offer_intro=true`、`do_not_intro_without_context=false`、`consent_scope` 明确 | 只显示确认问题，不生成文案 |

用户接受卡片只表示“愿意继续处理”，不表示 consent、give-first、network_path 或日程字段自动满足。

### 9.5 机会生命周期

关系经营机会必须有状态流转，避免只提醒不复盘。

```text
detected -> proposed -> accepted_by_user -> scheduled -> completed -> outcome_logged -> follow_up_created_or_closed -> closed
        \\-> blocked_pending_context -> proposed
                                      \\-> stale -> refreshed_or_closed
```

| 状态 | 触发事件 | 责任主体 | 退出条件 | 关闭/降级规则 |
| --- | --- | --- | --- | --- |
| `detected` | AI 识别线索 | AI | 通过最低字段检查 | 证据不足则降级为 source context |
| `blocked_pending_context` | 命中 blocker 但用户可补信息 | 用户 | 补齐关系阶段、give-first、consent、network_path 边证据 | 用户不补则 archive_fact_only 或 close |
| `proposed` | 进入整理台 | 用户 | 用户接受、编辑或拒绝 | 7 天未处理且无时间窗口则折叠 |
| `accepted_by_user` | 用户确认值得做 | 用户 | 创建日程、草稿或标记无需日程 | 用户编辑为仅存档则关闭机会 |
| `scheduled` | 通过日程协议 | 用户/系统提醒 | 用户完成或取消 | 到期未完成则转 `stale` |
| `stale` | 机会过期、无人处理、关系阶段/资源状态过期 | 用户 | 刷新证据、关闭或重新计划 | 不再高优先级展示 |
| `refreshed_or_closed` | 用户刷新或关闭 stale 机会 | 用户 | 新证据重新进入 proposed 或 closed | 避免无限重复提醒 |
| `completed` | 用户标记完成或后续记录证明 | 用户 | 填写 outcome | 无 outcome 时保留待复盘 |
| `outcome_logged` | 记录结果 | 用户 | 创建后续动作或关闭 | 失败结果降低同类建议强度 |
| `follow_up_created_or_closed` | 已根据 outcome 创建后续动作或决定关闭 | 系统/用户 | 关闭或进入新机会 | 避免重复提醒 |
| `closed` | 用户拒绝、过期、失败或不再相关 | 用户 | 无 | 不再主动提醒，保留历史 |

复盘字段：

- `outcome`: accepted/declined/no_response/not_relevant/completed_offline
- `relationship_effect`: improved/neutral/strained/unknown
- `follow_up_needed`: true/false
- `next_check_at_or_null`
- `lesson_for_future`: 用户确认后的偏好或边界
- `refresh_check_at_or_null`: 对 current_state/needs/network_path 的刷新时间
- `cadence_hint_or_null`: 沟通节奏，缺证据则 null
- `close_reason`: rejected_by_user/stale/no_response/consent_declined/not_actionable/merged_duplicate
- `future_suppression_rule`: suppress_same_type_for_person/suppress_until_date/none

outcome 反哺规则：

- `declined` 或 `consent_declined` 降低同一人同类机会建议强度。
- `strained` 关系效果会提高后续 `risk_penalty`。
- `accepted` 且效果 improved 可提高 trust_building 证据，但仍需来源。
- `no_response` 不等于关系恶化；只降低重复催促建议。

### 9.6 商业高价值样本

| 输入 | 正确处理 |
| --- | --- |
| May 在找实习，我可以把她介绍给 Alex | `relationship_opportunity/intro`, `priority_score`, `person_fact/needs` |
| Jason 认识做 AI 产品的校友 | `person_fact/resources`；若缺 trust_basis/同意/用户目标，`network_path_status=partial` 且不生成机会动作 |
| Alex 帮我改过简历，之后要请他吃饭感谢 | `relationship_memory/reciprocity_memory` + `reminder_source/thanks` |
| Chris 想认识数据分析方向的人，但我不确定要不要介绍 May | `relationship_opportunity/intro`, `needs_slot_confirmation`, `risk_note` |
| May 最近压力很大，我可以先发消息问候 | `relationship_opportunity/comfort` + possible `reminder_source/follow_up` |
| Jason 认识一个投资人，我想问他能不能介绍 | `relationship_opportunity/referral_request`, `requires_consent=true`, `ask_intermediary_first=true`, stage/risk required |
| May 让我把她介绍给 Alex | `relationship_opportunity/intro`, confirm Alex consent before sharing contact |
| Alex 上次帮我准备面试 | `relationship_memory/help_history`, `latent_relationship_affordance=thanks`; 只有用户表达感谢/回报/提醒/安排时才进入 thanks 机会 |
| Chris 最近不回消息 | `relationship_memory/dormant_or_risk_signal`, no aggressive follow-up |
| 我想找 Jason 要内推 | `relationship_opportunity/referral_request`, give-first framing and risk boundary required |

### 9.7 去重和合并

同一原文产生多个提案时，必须用同一个 `source_entry_id` 关联。

合并规则：

- 同一对象、同一时间窗口、同一动作类型的机会应合并。
- 同一 source_quote、同一 target、同一 profile category 的档案 patch 不重复。
- 同一关系边、同一事件上下文的 `relationship_memory` 不重复。
- 同一礼物触点和同一生日/纪念日触点应合并为一个机会，副卡保留事实。
- `reminder_source`、`gift_signal`、`person_fact` 可以共存，但标题和 `asset_value` 必须不同，避免整理台出现三张看似重复的卡。

## 10. 礼物线索边界

进入 `gift_signal`：

- 对方表达想要、喜欢、需要、讨厌、忌讳。
- 出现生日、节日、纪念日、感谢、道歉、祝贺等场合。
- 出现预算、惊喜、太贵、实用、不喜欢礼物等风险。

不要直接：

- 生成最终礼物。
- 把高风险礼物建议写成 confirmed fact。
- 把愿望只存成普通兴趣，丢掉关系经营价值。

示例：

| 输入 | 主卡 | 副卡 |
| --- | --- | --- |
| May 说想试拍立得 | `gift_signal` | `person_fact/interests` |
| Jason 不喜欢太贵的礼物 | `person_fact/spending_preference` | `gift_signal/risk` |
| Alex 生日快到了，但他不喜欢惊喜 | `gift_signal/risk` | `person_fact/anniversaries` |

## 11. 文件来源地位

`file_note` 不应和语义主类混在同一层。

推荐规则：

- 如果用户只是在描述来源：“这份 PDF 是 Jason 的简历”，主卡可为 `file_note`。
- 如果文件中包含可提取事实，`source_context=file`，语义主卡仍按内容决定。
- 文件事实写入朋友档案前必须保留来源和置信度。

示例：

| 输入 | 正确处理 |
| --- | --- |
| 这份 PDF 是 Jason 的简历 | `file_note` + person link |
| 从截图里看 May 周末不在学校 | `file_note/source_context` + `person_fact/current_state` |
| 这份 CSV 里 Alex 的微信是 alex2026 | `person_fact/contact` with source_context=file |

## 12. 高风险误判场景库

行程相关行必须给出 `schedule_subtype`、`schedule_execution_state`、`time_expression_kind`、`time_precision`、`commitment_level`、`needs_slot_confirmation`、`requires_user_approval`。所有 `PendingUpdate` 的 `requires_user_approval=true`；`needs_slot_confirmation=false` 只表示字段足够完整，不代表可以跳过用户批准。非行程负样本应明确 `schedule_execution_state=not_schedule`。

fixture 前置上下文：

| id | 类型 | 时间 | 人物 | 用途 |
| --- | --- | --- | --- | --- |
| `event_may_next_week` | future_event | 2026-06-24T15:00:00+08:00 | May | #53 anchored contextual guard |
| `event_wed` | future_event | 2026-06-24T15:00:00+08:00 | May | #54 ambiguous anchor candidate |
| `event_thu` | future_event | 2026-06-25T15:00:00+08:00 | May | #54 ambiguous anchor candidate |
| `reference_datetime_morning` | clock | 2026-06-19T10:00:00+08:00 | user | #1 afternoon-window candidate and validation JSON |
| `reference_datetime_evening` | clock | 2026-06-19T20:13:43+08:00 | user | #47-#55 future-trigger validation |

| # | 输入 | 常见误判 | 正确主卡 | 副卡/标记 | 判定理由 |
| --- | --- | --- | --- | --- | --- |
| 1 | 我要和 Jason 下午约个饭 | self/sensitive | `reminder_source/event` | subtype=`event`, state=`draft_schedule_candidate`, kind=`fuzzy_window`, precision=`half_day_window`, commitment=`committed`, `reference_datetime=2026-06-19T10:00:00+08:00`, `confirmation_blockers=[time_slot,notification_policy_missing]`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 用户参与未来活动；本行覆盖默认时钟，下午窗口仍在未来 |
| 2 | 我下周找 May 讨论项目 | self | `reminder_source/follow_up` | subtype=`follow_up`, state=`draft_schedule_candidate`, kind=`relative_window`, precision=`relative_window`, commitment=`intended`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 时间 + 用户动作 |
| 3 | 周五前把 Alex 的材料发掉 | person_fact | `reminder_source/deadline` | subtype=`deadline`, state=`draft_schedule_candidate`, kind=`relative_date`, precision=`date_only`, commitment=`committed`, `due_at={date, date_only}`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 截止前任务 |
| 4 | 明早给 Jason 发内推链接 | person_fact | `reminder_source/task` | subtype=`task`, state=`draft_schedule_candidate`, kind=`relative_window`, precision=`half_day_window`, commitment=`intended`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 发送动作 |
| 5 | 每周五问 May 论文进度 | person_fact | `reminder_source/recurring` | subtype=`recurring`, state=`draft_schedule_candidate`, kind=`recurring_rule`, precision=`date_only`, commitment=`committed`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 周期跟进 |
| 6 | 取消今晚和 Jason 的饭 | self | `reminder_source/cancel_existing` | subtype=`cancel_existing`, state=`existing_item_mutation`, kind=`fuzzy_window`, precision=`half_day_window`, commitment=`committed`, `match_status=ambiguous`, `can_approve_without_more_input=false`, `cancel_scope=unknown`, `confirmation_blockers=[mutation_match_ambiguous,cancel_scope_missing]`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 取消已有事项，不是新建 |
| 7 | 会议改到周五 | event new | `reminder_source/reschedule_existing` | subtype=`reschedule_existing`, state=`existing_item_mutation`, kind=`relative_date`, precision=`date_only`, commitment=`committed`, `match_status=ambiguous`, `can_approve_without_more_input=false`, `confirmation_blockers=[mutation_match_ambiguous,time_slot,notification_policy_missing]`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 改期需要匹配原事项，date-only 新时间不能直接执行 |
| 8 | 如果有空下周找 May | committed event | `reminder_source/follow_up` | subtype=`follow_up`, state=`draft_schedule_candidate`, kind=`relative_window`, precision=`relative_window`, commitment=`conditional`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 条件计划 |
| 9 | 上周和 Jason 吃饭了 | reminder | `relationship_memory` | state=`not_schedule`, temporal=`past` | 过去互动 |
| 10 | Jason 下周面试 | reminder | `person_fact/current_state` | state=`not_schedule`, `latent_relationship_affordance=congratulate`, no lifecycle | 朋友状态，无用户动作，不进入机会生命周期 |
| 11 | Jason 下周面试，我明天问问他 | person_fact only | `reminder_source/follow_up` | subtype=`follow_up`, state=`draft_schedule_candidate`, kind=`relative_date`, precision=`date_only`, commitment=`intended`, `needs_slot_confirmation=true`, `requires_user_approval=true`; `person_fact/current_state` | 下一步动作主导 |
| 12 | 今天准备考试时，我发现自己焦虑 | reminder | `context_only/no_workflow` | workflow_primary=null, workflow_primary_unit_id=null, domain_object=`episodic_self_state`, proposal_kind=`context_only`, state=`not_schedule`, `retention_policy=context_only`, `requires_discreet_review=false`; 若用户补充“想记一下这个状态”也只能进待确认反思候选 | 一次性情绪未必长期沉淀，不能把 `episodic_self_state` 当主卡 |
| 13 | 我怕 Jason 忘了材料 | self | `reminder_source/follow_up` | subtype=`follow_up`, state=`draft_schedule_candidate`, kind=`missing_time`, precision=`unresolved`, commitment=`intended`, `needs_slot_confirmation=true`, `requires_user_approval=true`; reason:担忧动机 | 担忧不是自我反思核心 |
| 14 | 我觉得 Alex 不吃香菜 | self | `person_fact/dietary_preference_or_avoidance` | state=`not_schedule`, lower confidence; allergy only if explicit | “觉得”是置信度 |
| 15 | Alex 喜欢薯片，不吃香菜 | self | `person_fact` | state=`not_schedule`, food/dietary | 稳定偏好 |
| 16 | May 不喜欢突然电话 | relationship | `person_fact/communication_preference` | state=`not_schedule`, boundary | 沟通偏好 |
| 17 | May 喜欢别人提前约 | reminder | `person_fact/communication_preference` | state=`not_schedule`, scheduling preference | 不是具体日程 |
| 18 | May 和 Alex 最近一起做项目 | person_fact | `relationship_memory` | state=`not_schedule`, collaboration | 两人互动 |
| 19 | Jason 介绍我认识了他导师 | person_fact | `relationship_memory` | state=`not_schedule`, resource intelligence | 新关系边 |
| 20 | 我和 Alex 最近聊得少了 | person_fact | `relationship_memory` | state=`not_schedule`, self if emotional | 关系变化 |
| 21 | 我不太想再和 Chris 单独吃饭 | reminder | `personal_reflection` | state=`not_schedule`, relationship risk | 边界/风险 |
| 22 | 下次见 May 别提她前任 | self | `person_fact/taboo_boundary` | subtype=`contextual_guard`, state=`contextual_guard_candidate`, anchor_status=`unmatched`, kind=`event_relative`, precision=`relative_window`, commitment=`committed`, `confirmation_blockers=[anchor_event_missing]`, `needs_slot_confirmation=true`, `requires_user_approval=true`; sensitive | 只能挂载到未来见面上下文 |
| 23 | May 说想试拍立得 | person_fact only | `gift_signal/touchpoint` | state=`not_schedule`, interests | 愿望主体是 May |
| 24 | Jason 不喜欢太贵的礼物 | plain fact only | `person_fact/spending_preference` | state=`not_schedule`, `gift_signal/risk` | 礼物风险 |
| 25 | Alex 生日是 8 月 3 日 | reminder only | `person_fact/anniversaries` | state=`not_schedule`, optional annual reminder | 生日先是事实 |
| 26 | Alex 生日提前一周提醒我 | person_fact only | `reminder_source/anniversary_reminder` | subtype=`anniversary_reminder`, state=`draft_schedule_candidate`, kind=`relative_window`, precision=`relative_window`, commitment=`committed`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 年度提醒 |
| 27 | May 最近在找实习 | reminder | `person_fact/current_state` | state=`not_schedule`, career_support_context only, no lifecycle | 朋友状态事实；无用户帮助/跟进意图时不进机会生命周期 |
| 28 | 我明天帮 May 改简历 | person_fact | `reminder_source/task` | subtype=`task`, state=`draft_schedule_candidate`, kind=`relative_date`, precision=`date_only`, commitment=`committed`, `needs_slot_confirmation=true`, `requires_user_approval=true`; help_history after completion | 用户动作 |
| 29 | May 帮我介绍了校友 | person_fact | `relationship_memory` | state=`not_schedule`, help_history/resource | 人情与资源 |
| 30 | 这份 PDF 是 Jason 的简历 | person_fact | `file_note` | state=`not_schedule`, person link | 来源本身有价值 |
| 31 | 截图里 May 说周末不在学校 | person_fact direct | `file_note/source_context` | state=`not_schedule`, `person_fact/current_state` | 文件来源要保留 |
| 32 | 我后悔昨天没回复 Alex | reminder | `context_only/no_workflow` | workflow_primary=null, workflow_primary_unit_id=null, domain_object=`episodic_self_state`, state=`not_schedule`, possible `relationship_memory`; 只有复盘/长期模式/保存意图才进 `personal_reflection` | 单次后悔不是默认长期反思 |
| 33 | 要不找 Jason 吃个饭？ | committed schedule | `reminder_source/event` | subtype=`event`, state=`draft_schedule_candidate`, kind=`missing_time`, precision=`unresolved`, commitment=`suggested`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 建议语气 |
| 34 | 找时间约 Alex 喝咖啡 | exact event | `reminder_source/event` | subtype=`event`, state=`draft_schedule_candidate`, kind=`missing_time`, precision=`unresolved`, commitment=`intended`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 待确认时间 |
| 35 | 不用提醒我交材料了 | new reminder | `reminder_source/update_existing` | subtype=`update_existing`, state=`existing_item_mutation`, kind=`missing_time`, precision=`unresolved`, commitment=`committed`, `match_status=ambiguous`, `can_approve_without_more_input=false`, `confirmation_blockers=[target_item]`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 修改已有提醒 |
| 36 | May 想暑假旅行 | user schedule | `person_fact/travel_preference` | state=`not_schedule`, gift/touchpoint if relevant | 欲望主体是 May |
| 37 | Jason 明天面试提醒我祝他好运 | Jason event | `reminder_source/follow_up` | subtype=`follow_up`, state=`draft_schedule_candidate`, kind=`relative_date`, precision=`date_only`, commitment=`intended`, `needs_slot_confirmation=true`, `requires_user_approval=true`; `person_fact/current_state` | 用户动作是祝福，不是参加面试 |
| 38 | May 让我周五前发材料 | plain message | `reminder_source/deadline` | subtype=`deadline`, state=`draft_schedule_candidate`, kind=`relative_date`, precision=`date_only`, commitment=`committed`, `due_at={date, date_only}`, `needs_slot_confirmation=true`, `requires_user_approval=true`; source_speaker=May | 外部请求形成用户截止任务 |
| 39 | 以后少和 Chris 单独吃饭 | recurring reminder | `personal_reflection` | state=`not_schedule`, `relationship_memory/risk_boundary` | 长期边界，不是具体日程 |
| 40 | 有空再约 Alex | executable reminder | `reminder_source/event` | subtype=`event`, state=`draft_schedule_candidate`, kind=`missing_time`, precision=`unresolved`, commitment=`conditional`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 只有意向，不能执行 |
| 41 | 每次见 May 前别提她前任 | standalone reminder | `person_fact/taboo_boundary` | subtype=`contextual_guard`, state=`contextual_guard_candidate`, anchor_status=`unmatched`, kind=`event_relative`, precision=`relative_window`, commitment=`committed`, `confirmation_blockers=[anchor_event_missing]`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 只能挂载上下文 |
| 42 | Jason 认识一个投资人，我想问他能不能介绍 | person_fact only | `relationship_opportunity/referral_request` | state=`not_schedule`, `person_fact/resources`, requires_consent, ask_intermediary_first, priority cap applies | 资源事实 + 用户请求意图 |
| 43 | May 让我把她介绍给 Alex | auto intro | `relationship_opportunity/intro` | state=`not_schedule`, ask_target_first, do_not_intro_without_context | May 同意不等于 Alex 同意 |
| 44 | Alex 上次帮我准备面试 | plain past event | `relationship_memory/help_history` | state=`not_schedule`, `latent_relationship_affordance=thanks`, no lifecycle | 帮助历史和互惠；无感谢/回报行动意图时不进机会生命周期 |
| 45 | Chris 最近不回消息 | high-pressure follow-up | `relationship_memory` | state=`not_schedule`, relationship_stage=`unknown` or `dormant_tie` if inactivity threshold met, risk_note | 关系风险，不宜强推 |
| 46 | 我想找 Jason 要内推 | simple reminder | `relationship_opportunity/referral_request` | state=`not_schedule`, relationship_stage, give_first_offer, consent/risk required | 请求资源需要关系和风险边界 |
| 47 | 6 月 21 日 15:00 和 Jason 开会，14:30 提醒我 | draft only | `reminder_source/event` | subtype=`event`, state=`executable_reminder`, kind=`exact_datetime`, precision=`exact_minute`, commitment=`committed`, `reference_datetime=2026-06-19T20:13:43+08:00`, `start_at=2026-06-21T15:00:00+08:00`, `remind_at=2026-06-21T14:30:00+08:00`, `notification_policy={delivery_mode:reminder,policy_source:user_explicit,trigger_at_or_null:2026-06-21T14:30:00+08:00,offset_or_null:null,next_trigger_at_or_null:null,timezone:Asia/Shanghai,requires_confirmation:false,default_allowed:false}`, `needs_slot_confirmation=false`, `requires_user_approval=true` | 事件时间和提醒时间分开，字段完整 |
| 48 | 明天 10:00 给 May 发材料 | draft only | `reminder_source/task` | subtype=`task`, state=`executable_reminder`, kind=`exact_datetime`, precision=`exact_minute`, commitment=`committed`, `reference_datetime=2026-06-19T20:13:43+08:00`, `remind_at=2026-06-20T10:00:00+08:00`, `notification_policy={delivery_mode:reminder,policy_source:user_explicit,trigger_at_or_null:2026-06-20T10:00:00+08:00,offset_or_null:null,next_trigger_at_or_null:null,timezone:Asia/Shanghai,requires_confirmation:false,default_allowed:false}`, `needs_slot_confirmation=false`, `requires_user_approval=true` | task 有明确提醒时间 |
| 49 | 6 月 26 日前提交 Alex 材料，6 月 25 日 18:00 提醒我 | date-only executable | `reminder_source/deadline` | subtype=`deadline`, state=`executable_reminder`, kind=`absolute_date`, precision=`date_only`, commitment=`committed`, `reference_datetime=2026-06-19T20:13:43+08:00`, `deadline_relation=before_or_on`, `due_at={date:2026-06-26,date_only:true}`, `remind_at=2026-06-25T18:00:00+08:00`, `notification_policy={delivery_mode:reminder,policy_source:user_explicit,trigger_at_or_null:2026-06-25T18:00:00+08:00,offset_or_null:null,next_trigger_at_or_null:null,timezone:Asia/Shanghai,requires_confirmation:false,default_allowed:false}`, `needs_slot_confirmation=false`, `requires_user_approval=true` | deadline 有 due date、边界语义和提醒策略 |
| 50 | 每周五 10:00 问 May 论文进度 | recurring candidate | `reminder_source/recurring` | subtype=`recurring`, state=`executable_reminder`, kind=`recurring_rule`, precision=`exact_minute`, commitment=`committed`, `reference_datetime=2026-06-19T20:13:43+08:00`, `recurrence_rule={frequency:weekly,interval:1,anchor_date:2026-06-19,by_weekday:Friday,remind_time_or_null:10:00,next_trigger_at_or_null:2026-06-26T10:00:00+08:00,end_condition_or_null:null,skip_or_exception_policy:ask,business_day_policy:null,calendar_system:Gregorian,timezone:Asia/Shanghai,timezone_dst_policy:null}`, `notification_policy={delivery_mode:reminder,policy_source:user_explicit,trigger_at_or_null:null,offset_or_null:null,next_trigger_at_or_null:2026-06-26T10:00:00+08:00,timezone:Asia/Shanghai,requires_confirmation:false,default_allowed:false}`, `needs_slot_confirmation=false`, `requires_user_approval=true` | recurring 规则完整且下一次触发晚于 reference_datetime |
| 51 | 6 月 21 日 15:00 提醒我和 Jason 开会 | start/reminder conflated | `reminder_source/event` | subtype=`event`, state=`draft_schedule_candidate`, kind=`exact_datetime`, time_role=`ambiguous`, precision=`exact_minute`, commitment=`committed`, `confirmation_blockers=[time_slot,notification_policy_missing]`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 15:00 可能是会议开始，也可能是提醒时间，必须确认 |
| 52 | 6 月 21 日 15:00 和 Jason 开会 | reminder default | `reminder_source/event` | subtype=`event`, state=`draft_schedule_candidate`, kind=`exact_datetime`, time_role=`event_start`, precision=`exact_minute`, commitment=`committed`, `start_at=2026-06-21T15:00:00+08:00`, `remind_at=null`, `notification_policy={delivery_mode:unspecified,policy_source:system_default_disallowed}`, `confirmation_blockers=[notification_policy_missing]`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 精确事件时间不等于提醒策略，不能自动 executable_reminder |
| 53 | 下周和 May 见面前别提她前任 | guard anchored | `person_fact/taboo_boundary` | subtype=`contextual_guard`, state=`anchored_contextual_guard`, anchor_status=`anchored`, `anchor_event_id=event_may_next_week`, `anchor_match_score=86`, `needs_slot_confirmation=false`, `requires_user_approval=true` | 已匹配未来事件，可挂载但仍需批准 |
| 54 | 下次见 May 前别提她前任，可能是周三或周四 | guard ambiguous | `person_fact/taboo_boundary` | subtype=`contextual_guard`, state=`contextual_guard_candidate`, anchor_status=`ambiguous`, `candidate_anchors=[event_wed,event_thu]`, `confirmation_blockers=[anchor_event_missing]`, `needs_slot_confirmation=true`, `requires_user_approval=true` | 多个候选锚点，必须用户选择 |
| 55 | 今天 10:00 提醒我给 May 发材料 | past trigger | `reminder_source/task` | subtype=`task`, state=`draft_schedule_candidate`, kind=`exact_datetime`, time_role=`reminder_trigger`, `reference_datetime=2026-06-19T20:13:43+08:00`, `remind_at=2026-06-19T10:00:00+08:00`, `confirmation_blockers=[past_trigger]`, `needs_slot_confirmation=true`, `requires_user_approval=true` | one-off 触发时间已过去，不能成为 executable_reminder |

高风险表的 blocker code 展开：

| 行号 | 必须包含的 `confirmation_blockers[*].code` |
| --- | --- |
| 1 | `time_slot`, `notification_policy_missing` |
| 2 | `time_slot`, `notification_policy_missing` |
| 3 | `date_only_due_without_reminder`, `deadline_relation_unknown` when relation cannot be parsed |
| 4 | `time_slot`, `notification_policy_missing` |
| 5 | `recurrence_policy`, `notification_policy_missing` |
| 6 | `mutation_match_ambiguous`, `cancel_scope_missing` |
| 7 | `mutation_match_ambiguous`, `time_slot`, `notification_policy_missing` |
| 8 | `time_slot`, `classification_ambiguity` |
| 11 | `time_slot`, `notification_policy_missing` |
| 13 | `time_slot`, `notification_policy_missing` |
| 22, 41 | `anchor_event_missing` |
| 26 | `time_slot`, `recurrence_policy`, `notification_policy_missing` |
| 28 | `time_slot`, `notification_policy_missing` |
| 33 | `time_slot`, `classification_ambiguity`, `notification_policy_missing` |
| 34 | `time_slot`, `notification_policy_missing` |
| 35 | `target_item` |
| 37 | `time_slot`, `notification_policy_missing` unless reminder trigger is explicit |
| 38 | `date_only_due_without_reminder`, `deadline_relation_unknown` when relation cannot be parsed |
| 40 | `time_slot`, `classification_ambiguity` |
| 51 | `time_slot`, `notification_policy_missing` |
| 52 | `notification_policy_missing` |
| 54 | `anchor_event_missing` |
| 55 | `past_trigger` |

三层分离强断言：

| 输入 | 必须断言 |
| --- | --- |
| Jason 最近准备面试，我明天问问他 | `semantic_primary_unit_id=u1` 指向 Jason current_state；`workflow_primary_unit_id=u2` 指向用户 follow-up；`workflow_primary=reminder_source/follow_up`；`secondary_workflows` 包含 `person_fact/current_state`；批准后 `storage_targets` 可同时包含 `reminder_source` 和 `person_fact` |
| Alex 生日是 8 月 3 日，提前一周提醒我 | `semantic_primary_unit_id=u1` 指向生日事实；`workflow_primary_unit_id=u2` 指向提醒 directive；事实批准不等于自动创建年度提醒 |
| 我想下午和 Jason 吃饭但有点尴尬 | `semantic_primary_unit_id` 指向 meal plan；尴尬 unit 的 `proposal_kind=context_only`；`storage_targets` 不包含 `personal_reflection` |

## 13. 输出验收格式

每条分类结果至少包含：

```json
{
  "primary_type": "reminder_source",
  "secondary_types": [],
  "proposition_units": [
    {
      "unit_id": "u1",
      "source_span": "我要和 Jason 下午约个饭",
      "propositional_content": "the user intends to have a meal with Jason this afternoon",
      "attitude_holder": "user",
      "intentional_mode": "intention",
      "direction_of_fit": "world_to_mind",
      "evidentiality": "direct_observation",
      "confidence_basis": "user reports their own intention",
      "domain_object": "schedule",
      "candidate_workflow": "reminder_source/event",
      "candidate_storage_targets": ["reminder_source"],
      "proposal_kind": "workflow_candidate"
    }
  ],
  "semantic_primary_unit_id": "u1",
  "workflow_primary_unit_id": "u1",
  "secondary_unit_ids": [],
  "semantic_primary": "u1:user meal plan with Jason",
  "workflow_primary": "reminder_source/event",
  "secondary_workflows": [],
  "storage_targets": ["reminder_source"],
  "retention_policy": "write_candidate",
  "illocutionary_force": "planning_declaration",
  "domain_frame": "schedule",
  "operation": "create",
  "semantic_roles": {
    "actor": "user",
    "target_person": "Jason",
    "desire_owner": null,
    "source_speaker": "user"
  },
  "intentional_layers": {
    "attitude_holder": "user",
    "intentional_mode": "intention",
    "direction_of_fit": "world_to_mind",
    "aboutness_target": "user and Jason's lunch plan",
    "propositional_content": "the user intends to have a meal with Jason this afternoon",
    "affective_bearer": null,
    "practical_target": "schedule candidate"
  },
  "temporal_status": "future",
  "time_expression_kind": "fuzzy_window",
  "time_precision": "half_day_window",
  "raw_time_expression": "下午",
  "time_role": "event_start",
  "reference_date": "2026-06-19",
  "reference_datetime": "2026-06-19T10:00:00+08:00",
  "timezone": "Asia/Shanghai",
  "resolved_window": {
    "start_after": "2026-06-19T12:00:00+08:00",
    "end_before": "2026-06-19T18:00:00+08:00",
    "requires_confirmation": true
  },
  "resolved_time": null,
  "start_at": null,
  "end_at": null,
  "due_at": null,
  "deadline_relation": null,
  "remind_at": null,
  "notification_policy": {
    "delivery_mode": "unspecified",
    "policy_source": "system_default_disallowed",
    "trigger_at_or_null": null,
    "offset_or_null": null,
    "next_trigger_at_or_null": null,
    "timezone": "Asia/Shanghai",
    "requires_confirmation": true,
    "default_allowed": false
  },
  "actionability": "ask_confirmation",
  "schedule_subtype": "event",
  "schedule_execution_state": "draft_schedule_candidate",
  "commitment_level": "committed",
  "location": null,
  "recurrence_rule": null,
  "mutation_match": null,
  "asset_value": [],
  "opportunity_type": "none",
  "sensitivity": "normal",
  "sensitivity_domain": "none",
  "severity": "none",
  "privacy_display_risk": "none",
  "visibility_preference": "default",
  "requires_discreet_review": false,
  "confidence": 0.86,
  "needs_slot_confirmation": true,
  "confirmation_blockers": [
    {
      "code": "time_slot",
      "field": "raw_time_expression",
      "required_for": "executable_reminder",
      "observed_value": "下午",
      "question": "你说的下午大概是几点？"
    },
    {
      "code": "notification_policy_missing",
      "field": "notification_policy",
      "required_for": "executable_reminder",
      "observed_value": {
        "delivery_mode": "unspecified",
        "trigger_at_or_null": null,
        "offset_or_null": null,
        "next_trigger_at_or_null": null
      },
      "question": "你希望我什么时候提醒你？"
    }
  ],
  "confirmation_reasons": ["time_slot", "notification_policy_missing"],
  "requires_user_approval": true,
  "ambiguous_slots": ["raw_time_expression"],
  "candidate_interpretations": [
    {
      "workflow_primary": "reminder_source/event",
      "reason": "用户表达了未来约饭安排"
    }
  ],
  "blocked_decision": "cannot_create_executable_reminder_until_time_and_notification_policy_confirmed",
  "confirmation_question": "你说的下午大概是几点？",
  "reason_summary": "原文包含用户参与的未来社交活动：下午和 Jason 约饭。虽然出现“我”，但没有表达自我反思或私密心理状态。",
  "confusion_guard": ["schedule_vs_reflection"]
}
```

人脉资产或关系机会类结果还必须附加：

```json
{
  "asset_dimension": "resources",
  "business_relevance": "Jason 可能连接 AI 产品投资人，但目前只是资源事实",
  "evidence_quote": "Jason 认识一个投资人",
  "observed_at": "2026-06-19",
  "expires_at_or_null": "2026-09-19",
  "opportunity_type": "none",
  "asset_value": ["resource_intelligence"],
  "recommended_next_action_or_null": null,
  "give_first_offer_or_null": null,
  "risk_boundary_or_null": "不要默认转发第三方联系方式",
  "relationship_stage": "unknown",
  "relationship_stage_confidence": 0.0,
  "stage_evidence_quote": null,
  "network_path": {
    "network_path_status": "partial",
    "from_person": "user",
    "via_person_or_group": "Jason",
    "to_person_or_resource": "investor",
    "trust_basis": null,
    "edges": [
      {
        "from": "user",
        "to": "Jason",
        "evidence_quote": null,
        "confidence": 0.0,
        "consent_status": "not_asked"
      },
      {
        "from": "Jason",
        "to": "investor",
        "evidence_quote": "Jason 认识一个投资人",
        "confidence": 0.7,
        "consent_status": "not_asked"
      }
    ],
    "action_consent_required": true,
    "path_confidence": 0.0
  },
  "why_no_action": {
    "reason": "asset_fact_only_no_user_action_intent",
    "not_a_blocked_opportunity": true,
    "explanations": [
      {
        "code": "no_user_request_intent",
        "evidence_quote": "Jason 认识一个投资人",
        "explanation": "用户只陈述资源事实，没有提出请求或引荐目标"
      },
      {
        "code": "missing_relationship_stage_evidence",
        "evidence_quote": null,
        "explanation": "没有用户和 Jason 的关系阶段证据"
      },
      {
        "code": "missing_give_first_or_reciprocity",
        "evidence_quote": null,
        "explanation": "没有 give-first 或互惠基础"
      },
      {
        "code": "action_consent_not_confirmed",
        "evidence_quote": null,
        "explanation": "未获得 Jason 或第三方对引荐/联系方式分享的行动同意；这不影响事实存档"
      }
    ]
  },
  "action_gates_if_user_requests_intro": {
    "requires_user_goal": true,
    "requires_relationship_stage_evidence": true,
    "requires_give_first_or_reciprocity": true,
    "requires_action_consent": true,
    "requires_allowed_information": true
  },
  "priority_score": null,
  "fact_storage_external_consent_required": false,
  "action_consent_required": true,
  "requires_consent": null,
  "ask_target_first": null,
  "ask_intermediary_first": null,
  "safe_to_offer_intro": false,
  "do_not_intro_without_context": true,
  "consent_scope": null,
  "proposed_consent_scope_if_user_requests_intro": ["project_context", "background"],
  "allowed_information": null,
  "proposed_allowed_information_if_user_requests_intro": ["user_name", "project_summary", "reason_for_intro"],
  "consent_source": "unknown",
  "consent_observed_at": null,
  "consent_expires_at_or_null": null,
  "consent_withdrawn": false,
  "party_consents": {
    "Jason": "not_asked",
    "investor": "not_asked"
  },
  "action_template": null,
  "blocked_decision": null,
  "card_type": "asset_fact_card",
  "not_card_type": "blocked_opportunity_confirmation",
  "opportunity_lifecycle_state": null,
  "outcome": null,
  "relationship_effect": "unknown",
  "follow_up_needed": null
}
```

对当前 schema 的落地方式：

- `primary_type` 继续映射到现有 `MemoryAtomType` 或 profile patch。
- 正交字段先进入 prompt、review explanation、fixtures 和测试期望。
- 若短期不改 schema，可把结构化字段放入 envelope 的 `structuredContext` / `reviewExplanation`。
- 若后续改 schema，必须单独评审数据库迁移风险。

## 14. 回归测试矩阵

行程类必须至少覆盖：

1. 精确事件但无提醒策略：`6 月 21 日 15:00 和 Jason 开会`
2. 只有日期：`周五前提交 Alex 的材料`
3. 相对日期：`下周三问 May 论文进度`
4. 模糊时间：`下午和 Jason 约饭`
5. 无时间待办：`找 May 聊项目`
6. 周期提醒：`每周五问 May 论文进度`
7. 取消：`取消今晚和 Jason 的饭`
8. 改期：`会议改到周五`
9. 过去事件：`上周和 Jason 吃饭了`
10. 假设计划：`如果有空下周找 May`
11. 朋友状态无动作：`Jason 下周面试`
12. 朋友状态有跟进：`Jason 下周面试，我明天问问他`
13. 朋友事件触发用户祝福：`Jason 明天面试提醒我祝他好运`
14. 外部请求形成 deadline：`May 让我周五前发材料`
15. 长期边界不是日程：`以后少和 Chris 单独吃饭`
16. 条件性邀约：`有空再约 Alex`
17. 上下文禁忌提醒：`每次见 May 前别提她前任`
18. 可执行 event 正例：`6 月 21 日 15:00 和 Jason 开会，14:30 提醒我`
19. 可执行 task 正例：`明天 10:00 给 May 发材料`
20. 可执行 deadline 正例：`6 月 26 日前提交 Alex 材料，6 月 25 日 18:00 提醒我`
21. 可执行 recurring 正例：`每周五 10:00 问 May 论文进度`
22. 事件时间/提醒时间歧义：`6 月 21 日 15:00 提醒我和 Jason 开会`
23. anchored contextual guard 正例：`下周和 May 见面前别提她前任`
24. ambiguous contextual guard 正例：`下次见 May 前别提她前任，可能是周三或周四`
25. one-off 过去触发负例：`今天 10:00 提醒我给 May 发材料`

每个行程 fixture 都必须断言：

- `schedule_subtype`
- `schedule_execution_state`
- `time_expression_kind`
- `time_precision`
- `commitment_level`
- `needs_slot_confirmation`
- `requires_user_approval`
- `start_at` / `due_at` / `remind_at` 的正确空值或非空值
- `time_role`、`deadline_relation`、`notification_policy.delivery_mode`、`reference_datetime` 的正确值
- `trigger_at_or_null` / `next_trigger_at_or_null` 必须晚于 `reference_datetime`
- `due_at` date-only 不能被静默转成 timestamp
- date-only 不自动补全具体时间
- mutation 必须匹配既有事项
- contextual guard 不能 standalone 执行
- `confirmation_blockers` 必须结构化，且 `confirmation_reasons` 只能由 blocker code 派生

其他高风险组：

- 情绪词但非反思：`我怕 Jason 忘了材料`
- 时间词但非日程：`我害怕明天考试`
- 愿望词但非用户礼物：`May 想暑假旅行`
- 朋友名但非档案更新：`我和 Alex 聊完发现自己太急`
- 文件来源：`截图里 May 说周末不在学校`
- 边界/否定：`我不想和 Chris 单独吃饭`
- 愿望主体不是用户：`May 想暑假旅行`
- 资源事实不等于可引荐：`Jason 认识一个投资人`
- 单方同意不等于双方同意：`May 让我把她介绍给 Alex`
- 帮助历史不是普通 past event：`Alex 上次帮我准备面试`
- 冷却关系不该强推：`Chris 最近不回消息`

商业执行类 fixture 必须断言：

- `priority_score_audit.raw_score` 与 `priority_score` 可复算；旧 `priority_score_breakdown` 只能作为兼容别名，不得另起一套解释。
- 上限规则能限制低证据、低关系阶段置信、缺同意策略、过期资源和弱关系索取。
- `requires_consent`、`ask_target_first`、`ask_intermediary_first`、`do_not_intro_without_context` 在引荐/联系方式场景正确出现。
- `give_first_offer_or_null` 缺失时，`ask/referral_request/intro` 不能生成索取动作，只能生成补充上下文确认卡。
- `relationship_stage` 和 `relationship_stage_confidence` 可被用户纠错。
- 过期的 `current_state/needs/access_to_network` 不生成高优先级机会。
- 冷关系、敏感关系和不回消息场景不强推主动触达。
- `opportunity_lifecycle_state` 进入、退出、关闭规则可验证。

商业执行样本最低集：

| 输入 | 预期 |
| --- | --- |
| May 生日快到了，她说想试拍立得 | no lifecycle by default; `latent_relationship_affordance=gift`; enters `opportunity_type=gift` only if user asks to plan/buy/remind |
| Jason 明天面试 | no lifecycle by default; `latent_relationship_affordance=congratulate`; enters opportunity only with explicit follow-up/reminder/help intent |
| May 最近压力很大，我可以晚上问候她吗 | explicit user action intent; `opportunity_type=comfort`, risk_penalty for timing, channel low-intrusion |
| Alex 上次帮我准备面试 | no lifecycle by default; `latent_relationship_affordance=thanks`, no ask; enters opportunity only if user asks to thank/return favor |
| May 让我把她介绍给 Alex | `opportunity_type=intro`, blocker until Alex consent scope known |
| 周五前跟 May 确认项目材料 | `opportunity_type=follow_up`, may convert to reminder if schedule fields pass |
| 下次见 May 前别提她前任 | `opportunity_type=risk_reduction`, contextual_guard only |
| Jason 认识投资人 | no actionable opportunity card; only `asset_fact_card` / `person_fact/resources`, score null |
| 我想找 Jason 要内推但不知道能给他什么 | blocker: missing give-first/reciprocity; create confirmation card only |

最低验收：

- “我要和 Jason 下午约个饭。” -> `reminder_source/event`, `sensitivity=normal`
- “我想下午和 Jason 吃饭但有点尴尬。” -> primary `reminder_source/event`; 尴尬只是 secondary episodic context
- “今天准备考试时，我发现自己有点焦虑。” -> `episodic_self_state` context，不直接写长期 `personal_reflection`
- “今天准备考试时，我发现自己有点焦虑，想记一下这个状态。” -> `personal_reflection` candidate
- “Alex 喜欢薯片，不吃香菜。” -> `person_fact`, not reflection
- “Jason 最近准备面试，我明天问问他。” -> primary `reminder_source/follow_up`, secondary `person_fact/current_state`
- “May 和 Alex 最近一起做项目。” -> `relationship_memory`
- “May 说想试拍立得。” -> `gift_signal/touchpoint`
- “我不太想再和 Chris 单独吃饭。” -> not `reminder_source`

建议验证命令：

```bash
cd macos
swift run MemoriaProtocolChecks
swift build

cd ..
bash ./script/build_and_run.sh --verify
```

## 15. 实施分层建议

### Phase 1：Prompt 与本地 fallback 同步

- Prompt 增加正交字段和高风险混淆规则。
- 本地 fallback 使用同一套候选信号函数，避免无 key 时语义相反。
- 为 `routeInput` 和 `extractMemory` 加入反例样本。

### Phase 2：结构化路由解释

- 给待审 envelope 增加 `proposition_units`、`semantic_primary_unit_id`、`workflow_primary_unit_id`、`secondary_workflows`、`reason_summary`、`confusion_guard`、`needs_slot_confirmation`、`confirmation_reasons`、`requires_user_approval`。
- 整理台展示“为什么进这个分区”以及“为什么不是另一个分区”。
- 对低 confidence 或高混淆卡片，默认要求用户确认分类。

### Phase 3：日程可执行性

- 在结构化上下文中保留 `schedule_subtype`、`schedule_execution_state`、`time_role`、`time_expression_kind`、`time_precision`、`commitment_level`、`start_at`、`due_at`、`deadline_relation`、`remind_at`、`notification_policy`、`confirmation_blockers`、`needs_slot_confirmation`、`requires_user_approval`。
- 支持 `cancel_existing`、`reschedule_existing`、`update_existing` 类型先匹配已有提醒，匹配不到则进入待确认。
- birthday/anniversary 优先写档案事实，再询问是否建立年度提醒。

### Phase 4：人脉资产化

- 将 `asset_value` 写入 review explanation 或后续 structured context。
- 将 `priority_score_audit`、`network_path`、`relationship_stage_confidence`、`relationship_value` 拆分项写入机会类 review explanation。
- 对朋友当前状态、资源、需求、帮助历史、沟通节奏设置过期或刷新提示。
- 增加 `relationship_opportunity` 辅助提案，短期可投影到 `gift_signal` 或 `reminder_source`。
- 为机会增加生命周期状态：detected/proposed/accepted/scheduled/completed/outcome_logged/closed。

### Phase 5：样本库和评分门禁

- 建立 `classification_edge_cases.json` 或 Swift fixture。
- 每条样本包含 input、expected primary type、expected secondary types、proposition units、sensitivity、visibility/discreet flags、review category、reason keywords、negative guards。
- 每次修改 prompt/fallback/schema 时先跑边界样本。

## 16. 质量评分标准

每次分类优化必须通过 100 分制审核，任何一项低于 95 分即打回。

| 维度 | 权重 | 95 分标准 |
| --- | ---: | --- |
| 概念边界 | 20 | 明确分离 `proposition_units`、`semantic_primary`、唯一 `workflow_primary`、`secondary_workflows`、`storage_targets`，并区分话语行为、意向态度、认识论标记、自我内容、行动对象 |
| 行程可执行性 | 20 | 能区分 candidate/executable reminder/executable schedule item/contextual guard candidate/anchored guard/mutation，并正确处理 subtype 阈值、时间角色、通知策略、解析窗口、`start_at`/`due_at`/`deadline_relation`/`remind_at`、date-only due object、重复、取消范围、改期、过去事件、`confirmation_blockers`、`needs_slot_confirmation` 与 `requires_user_approval` |
| 人脉资产价值 | 20 | 朋友档案、关系网络、资源、需求、帮助历史、可复现机会评分、上限/阻断项、同意边界、relationship_stage 置信度、network_path、give-first 门槛、风险、过期刷新、动作模板和生命周期都不丢 |
| 隐私与敏感性 | 15 | 普通行程不误标 `sensitivity=sensitive` 或私密展示；真实心理/健康/冲突能触发 `sensitive`、`requires_discreet_review` 或用户确认展示偏好 |
| 多提案与去重 | 10 | 复杂输入能拆主副提案，不制造重复卡 |
| 歧义处理 | 10 | 低置信、代词、人名歧义、时间不完整时能提确认问题 |
| 回归覆盖 | 5 | 覆盖正例和“看似该类但不该归入”的负样本 |

## 17. 盲审流程

本方案需要三类独立盲审：

1. 哲学教授：审查事实陈述、自我反思、意向性和概念层级。
2. 人际管理大师：审查朋友档案、关系网络、资源线索、机会和风险。
3. 行程规划师/私人管家：审查计划、提醒、日程、待办、跟进、重复、取消、改期。

流程：

1. 三位评审只看同一版草案，不看彼此意见。
2. 每人给 0-100 分和最多 8 条高优先级意见。
3. 任一评分低于 95，必须按该角色意见重写对应章节。
4. 三人都达到 95 以上，才能进入代码实现计划。

## 18. 第十六轮盲审结果

| 角色 | 分数 | 结论 |
| --- | ---: | --- |
| 哲学教授 | 96 | 通过：`episodic_self_state`、`durable_self_pattern`、no-workflow 哨兵、显式行动意图和事实陈述边界清楚；“我要和 Jason 下午约饭”稳定落在 planning/schedule。 |
| 人际管理大师 | 97 | 通过：无行动意图的关系触点只保留 `latent_relationship_affordance` 或事实/触点卡；显式行动意图才进入 gated `relationship_opportunity`；资源事实、同意边界和 give-first 门槛过线。 |
| 行程规划师/私人管家 | 97 | 通过：#1 Jason 下午约饭时钟自洽，非显式提醒不预设 `reminder`，时间槽和通知策略均阻断；past trigger、改期、取消和 contextual guard 边界清楚。 |

实现注意点：

- 无行动 `gift_signal/touchpoint` 不能被 UI 文案包装成“建议你行动”的机会卡。
- #4/#11/#37 等非显式提醒 fixture 要显式断言 `notification_policy_missing`，避免只补时间后误升 executable reminder。
- `我想给 May 买生日礼物` 应补进实现期 fixture 最低集，验证显式购买意图能进入 gated `relationship_opportunity/gift`，但长期事实仍只写 `gift_signal` / `person_fact`。
