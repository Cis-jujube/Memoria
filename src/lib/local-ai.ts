export const deepSeekModels = ["deepseek-v4-flash", "deepseek-v4-pro"] as const;
export type DeepSeekModel = (typeof deepSeekModels)[number];

export const languagePreferences = ["system", "zh-CN", "en"] as const;
export type LanguagePreference = (typeof languagePreferences)[number];

export type DeepSeekChatRequest = {
  model: DeepSeekModel;
  messages: {
    role: "system" | "user";
    content: string;
  }[];
  response_format: {
    type: "json_object";
  };
  thinking: {
    type: "enabled" | "disabled";
  };
  reasoning_effort?: "high";
  temperature: number;
  max_tokens: number;
  stream: false;
};

export type DeepSeekExtractionRequestInput = {
  text: string;
  model: DeepSeekModel;
  deepThinking: boolean;
  locale: string;
  timezone: string;
};

const extractionJsonInstruction = `Return only valid JSON. Do not include markdown or prose.
The JSON object must use this exact top-level shape:
{
  "people": [],
  "reminders": [],
  "giftIdeas": []
}
Each people item may include displayName, relationLabel, and updates.
Each update must include type, fieldPath, proposedValue, summary, evidence, and confidence.
Use empty arrays when the note does not contain evidence.`;

const extractionSystemPrompt =
  "Extract friend relationship facts from student-life notes. Keep sensitive facts minimal, evidence-backed, and ready for human review before saving.";

export function buildDeepSeekChatRequest(
  input: DeepSeekExtractionRequestInput,
): DeepSeekChatRequest {
  const request: DeepSeekChatRequest = {
    model: normalizeDeepSeekModel(input.model),
    messages: [
      {
        role: "system",
        content: `${extractionSystemPrompt}\n${extractionJsonInstruction}`,
      },
      {
        role: "user",
        content: `Locale: ${input.locale}\nTimezone: ${input.timezone}\nNote:\n${input.text}`,
      },
    ],
    response_format: { type: "json_object" },
    thinking: { type: input.deepThinking ? "enabled" : "disabled" },
    temperature: 0.1,
    max_tokens: 1600,
    stream: false,
  };

  if (input.deepThinking) {
    request.reasoning_effort = "high";
  }

  return request;
}

export function normalizeDeepSeekModel(model: string): DeepSeekModel {
  return deepSeekModels.includes(model as DeepSeekModel)
    ? (model as DeepSeekModel)
    : "deepseek-v4-flash";
}

export function normalizeLanguagePreference(
  language: string | null | undefined,
): LanguagePreference {
  return languagePreferences.includes(language as LanguagePreference)
    ? (language as LanguagePreference)
    : "system";
}

export type NativeCopy = {
  aiInboxTitle: string;
  whySuggested: string;
  settingsTitle: string;
  deepSeekSectionTitle: string;
  apiKeyPlaceholder: string;
  saveKey: string;
  testConnection: string;
  removeKey: string;
  modelLabel: string;
  deepThinkingLabel: string;
  languageLabel: string;
  deepseekPrivacyNote: string;
  missingKeyMessage: string;
};

const zhCopy: NativeCopy = {
  aiInboxTitle: "待确认",
  whySuggested: "为什么建议这样记",
  settingsTitle: "设置",
  deepSeekSectionTitle: "DeepSeek 接入",
  apiKeyPlaceholder: "粘贴你的 DeepSeek API key",
  saveKey: "保存密钥",
  testConnection: "测试连接",
  removeKey: "移除密钥",
  modelLabel: "模型",
  deepThinkingLabel: "深度思考",
  languageLabel: "界面语言",
  deepseekPrivacyNote:
    "开启 AI 识别后，你输入的记忆内容会发送给 DeepSeek 处理。密钥只保存在本机安全存储里，不写进本地数据库。",
  missingKeyMessage: "还没有保存 DeepSeek API key。先去设置里填一下，再用 AI 识别。",
};

const enCopy: NativeCopy = {
  aiInboxTitle: "AI Inbox",
  whySuggested: "Why AI suggested this",
  settingsTitle: "Settings",
  deepSeekSectionTitle: "DeepSeek",
  apiKeyPlaceholder: "Paste your DeepSeek API key",
  saveKey: "Save key",
  testConnection: "Test connection",
  removeKey: "Remove key",
  modelLabel: "Model",
  deepThinkingLabel: "Deep thinking",
  languageLabel: "Language",
  deepseekPrivacyNote:
    "AI capture sends the text you enter to DeepSeek. Your API key stays in local secure storage and is not written to SQLite.",
  missingKeyMessage:
    "No DeepSeek API key is saved yet. Add one in Settings before using AI capture.",
};

export function getNativeCopy(language: LanguagePreference): NativeCopy {
  return language === "zh-CN" ? zhCopy : enCopy;
}
