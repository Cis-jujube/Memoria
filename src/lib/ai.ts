import OpenAI from "openai";
import { z } from "zod";

const AI_PROVIDERS = ["openai", "deepseek"] as const;

export type AIProvider = (typeof AI_PROVIDERS)[number];
export const DEEPSEEK_MODELS = ["deepseek-v4-flash", "deepseek-v4-pro"] as const;
export type DeepSeekModel = (typeof DEEPSEEK_MODELS)[number];
export type DeepSeekRequestOptions = {
  apiKey?: string;
  baseURL?: string;
  model?: DeepSeekModel;
  thinkingEnabled?: boolean;
};

const updateTypeSchema = z.enum([
  "PROFILE_FACT",
  "PREFERENCE",
  "EVENT",
  "REMINDER",
  "GIFT_IDEA",
  "RELATIONSHIP",
  "FILE_NOTE",
]);

const extractionUpdateSchema = z.object({
  type: updateTypeSchema,
  fieldPath: z.string().min(1),
  proposedValue: z.unknown(),
  summary: z.string().min(1),
  evidence: z.string().min(1),
  confidence: z.number().min(0).max(1).default(0.75),
});

const extractionPersonSchema = z.object({
  displayName: z.string().trim().min(1),
  relationLabel: z.string().trim().optional(),
  updates: z.array(extractionUpdateSchema).default([]),
});

const extractionReminderSchema = z.object({
  personName: z.string().trim().min(1).optional(),
  title: z.string().trim().min(1),
  dueAt: z.string().datetime(),
  evidence: z.string().min(1),
  confidence: z.number().min(0).max(1).default(0.75),
});

const extractionGiftSchema = z.object({
  personName: z.string().trim().min(1),
  title: z.string().trim().min(1),
  rationale: z.string().trim().min(1),
  priceBand: z.string().trim().optional(),
  sourceFacts: z.array(z.string().trim().min(1)).default([]),
});

export const extractionPayloadSchema = z.object({
  people: z.array(extractionPersonSchema).default([]),
  reminders: z.array(extractionReminderSchema).default([]),
  giftIdeas: z.array(extractionGiftSchema).default([]),
});

export type ExtractionPayload = z.infer<typeof extractionPayloadSchema>;
export type PendingUpdateType = z.infer<typeof updateTypeSchema>;

export type NormalizedPendingUpdate = {
  userId: string;
  personName?: string;
  type: PendingUpdateType;
  fieldPath: string;
  proposedValue: unknown;
  summary: string;
  evidence: string;
  sourceType: string;
  sourceId?: string;
  confidence: number;
};

export type ExtractionInput = {
  text: string;
  timezone?: string;
  locale?: string;
};

export const MAX_PENDING_UPDATES_PER_CAPTURE = 12;

const extractionJsonSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    people: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          displayName: { type: "string" },
          relationLabel: { type: "string" },
          updates: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              properties: {
                type: {
                  type: "string",
                  enum: [
                    "PROFILE_FACT",
                    "PREFERENCE",
                    "EVENT",
                    "RELATIONSHIP",
                    "FILE_NOTE",
                  ],
                },
                fieldPath: { type: "string" },
                proposedValue: {},
                summary: { type: "string" },
                evidence: { type: "string" },
                confidence: { type: "number" },
              },
              required: [
                "type",
                "fieldPath",
                "proposedValue",
                "summary",
                "evidence",
                "confidence",
              ],
            },
          },
        },
        required: ["displayName", "relationLabel", "updates"],
      },
    },
    reminders: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          personName: { type: "string" },
          title: { type: "string" },
          dueAt: { type: "string" },
          evidence: { type: "string" },
          confidence: { type: "number" },
        },
        required: ["personName", "title", "dueAt", "evidence", "confidence"],
      },
    },
    giftIdeas: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          personName: { type: "string" },
          title: { type: "string" },
          rationale: { type: "string" },
          priceBand: { type: "string" },
          sourceFacts: {
            type: "array",
            items: { type: "string" },
          },
        },
        required: [
          "personName",
          "title",
          "rationale",
          "priceBand",
          "sourceFacts",
        ],
      },
    },
  },
  required: ["people", "reminders", "giftIdeas"],
} as const;

const extractionJsonInstruction = `Return only a valid JSON object, with no markdown, comments, or prose.
The JSON object must match this shape:
{
  "people": [
    {
      "displayName": "string",
      "relationLabel": "string",
      "updates": [
        {
          "type": "PROFILE_FACT | PREFERENCE | EVENT | RELATIONSHIP | FILE_NOTE",
          "fieldPath": "string",
          "proposedValue": "any JSON value",
          "summary": "string",
          "evidence": "string",
          "confidence": 0.75
        }
      ]
    }
  ],
  "reminders": [
    {
      "personName": "string",
      "title": "string",
      "dueAt": "ISO-8601 datetime string",
      "evidence": "string",
      "confidence": 0.75
    }
  ],
  "giftIdeas": [
    {
      "personName": "string",
      "title": "string",
      "rationale": "string",
      "priceBand": "string",
      "sourceFacts": ["string"]
    }
  ]
}
Use empty arrays when there is no evidence.`;

const systemExtractionPrompt =
  "Extract friend relationship facts from student-life notes. Return only structured JSON data. Keep sensitive facts minimal and evidence-backed.";

function userExtractionPrompt(input: ExtractionInput) {
  return `Locale: ${input.locale || "zh-CN/en-US"}\nTimezone: ${
    input.timezone || "local"
  }\nNote:\n${input.text}`;
}

export function parseExtractionPayload(input: unknown): ExtractionPayload {
  return extractionPayloadSchema.parse(input);
}

export function normalizeExtractionToPendingUpdates({
  userId,
  sourceId,
  sourceType,
  extraction,
}: {
  userId: string;
  sourceId?: string;
  sourceType: string;
  extraction: ExtractionPayload;
}): NormalizedPendingUpdate[] {
  const personUpdates = extraction.people.flatMap((person) =>
    person.updates.map((update) => ({
      userId,
      personName: person.displayName.trim(),
      type: update.type,
      fieldPath: update.fieldPath,
      proposedValue: update.proposedValue,
      summary: update.summary,
      evidence: update.evidence,
      sourceType,
      sourceId,
      confidence: update.confidence,
    })),
  );

  const reminderUpdates = extraction.reminders.map((reminder) => ({
    userId,
    personName: reminder.personName,
    type: "REMINDER" as const,
    fieldPath: "reminders",
    proposedValue: {
      title: reminder.title,
      dueAt: reminder.dueAt,
    },
    summary: reminder.title,
    evidence: reminder.evidence,
    sourceType,
    sourceId,
    confidence: reminder.confidence,
  }));

  const giftUpdates = extraction.giftIdeas.map((gift) => ({
    userId,
    personName: gift.personName,
    type: "GIFT_IDEA" as const,
    fieldPath: "giftIdeas",
    proposedValue: {
      title: gift.title,
      rationale: gift.rationale,
      priceBand: gift.priceBand,
      sourceFacts: gift.sourceFacts,
    },
    summary: gift.title,
    evidence: gift.rationale,
    sourceType,
    sourceId,
    confidence: 0.75,
  }));

  return [...personUpdates, ...reminderUpdates, ...giftUpdates].slice(
    0,
    MAX_PENDING_UPDATES_PER_CAPTURE,
  );
}

export async function extractFriendMemory(
  input: ExtractionInput,
  options: { deepSeek?: DeepSeekRequestOptions } = {},
) {
  const userDeepSeek = normalizeDeepSeekOptions(options.deepSeek);
  const provider = userDeepSeek?.apiKey ? "deepseek" : resolveAIProvider();
  const apiKey =
    provider === "deepseek"
      ? userDeepSeek?.apiKey || process.env.DEEPSEEK_API_KEY
      : process.env.OPENAI_API_KEY;
  const allowFallback =
    process.env.NODE_ENV !== "production" ||
    process.env.AI_MOCK_FALLBACK === "true";

  if (!apiKey) {
    if (!allowFallback) {
      throw new Error(
        provider === "deepseek"
          ? "DEEPSEEK_API_KEY is required for production AI extraction"
          : "OPENAI_API_KEY is required for production AI extraction",
      );
    }
    return buildLocalFallbackExtraction(input.text);
  }

  if (provider === "deepseek") {
    return extractWithDeepSeek(input, apiKey, userDeepSeek || undefined);
  }

  return extractWithOpenAI(input, apiKey);
}

export function resolveAIProvider(): AIProvider {
  const configured = process.env.AI_PROVIDER?.trim().toLowerCase();

  if (configured) {
    if (AI_PROVIDERS.includes(configured as AIProvider)) {
      return configured as AIProvider;
    }

    throw new Error(`Unsupported AI_PROVIDER: ${configured}`);
  }

  if (process.env.DEEPSEEK_API_KEY?.trim() && !process.env.OPENAI_API_KEY?.trim()) {
    return "deepseek";
  }

  return "openai";
}

async function extractWithOpenAI(
  input: ExtractionInput,
  apiKey: string,
): Promise<ExtractionPayload> {
  const client = new OpenAI({ apiKey });
  const response = await client.responses.create({
    model: process.env.OPENAI_MODEL || "gpt-5.5",
    input: [
      {
        role: "system",
        content: systemExtractionPrompt,
      },
      {
        role: "user",
        content: userExtractionPrompt(input),
      },
    ],
    text: {
      format: {
        type: "json_schema",
        name: "friend_memory_extraction",
        strict: true,
        schema: extractionJsonSchema,
      },
    },
  });

  const textOutput = response.output_text;
  if (!textOutput) {
    throw new Error("OpenAI returned an empty extraction response");
  }

  return parseExtractionPayload(JSON.parse(textOutput));
}

async function extractWithDeepSeek(
  input: ExtractionInput,
  apiKey: string,
  options?: DeepSeekRequestOptions,
): Promise<ExtractionPayload> {
  const client = new OpenAI({
    apiKey,
    baseURL: options?.baseURL || process.env.DEEPSEEK_BASE_URL || "https://api.deepseek.com",
  });

  const response = await client.chat.completions.create(buildDeepSeekChatRequest({
    model: options?.model || resolveDeepSeekModel(process.env.DEEPSEEK_MODEL),
    messages: [
      {
        role: "system",
        content: `${systemExtractionPrompt}\n${extractionJsonInstruction}`,
      },
      {
        role: "user",
        content: userExtractionPrompt(input),
      },
    ],
    thinkingEnabled: options?.thinkingEnabled || false,
  }) as never);

  const textOutput = stringifyChatMessageContent(
    response.choices[0]?.message?.content,
  );

  if (!textOutput) {
    throw new Error("DeepSeek returned an empty extraction response");
  }

  return parseExtractionPayload(JSON.parse(textOutput));
}

export async function testDeepSeekConnection(options: DeepSeekRequestOptions) {
  const normalized = normalizeDeepSeekOptions(options);
  if (!normalized?.apiKey) {
    throw new Error("DeepSeek API key is required");
  }

  const client = new OpenAI({
    apiKey: normalized.apiKey,
    baseURL: normalized.baseURL || process.env.DEEPSEEK_BASE_URL || "https://api.deepseek.com",
  });

  const model = normalized.model || "deepseek-v4-flash";
  const response = await client.chat.completions.create(buildDeepSeekChatRequest({
    maxTokens: 256,
    messages: [
      {
        role: "system",
        content: "Return only JSON. Do not include markdown.",
      },
      {
        role: "user",
        content: 'Return {"ok":true,"service":"deepseek"}',
      },
    ],
    model,
    thinkingEnabled: normalized.thinkingEnabled || false,
  }) as never);

  const textOutput = stringifyChatMessageContent(response.choices[0]?.message?.content);
  if (!textOutput) {
    throw new Error("DeepSeek returned an empty test response");
  }

  let parsed: { ok?: boolean; service?: string };
  try {
    parsed = JSON.parse(textOutput) as { ok?: boolean; service?: string };
  } catch {
    throw new Error("DeepSeek responded, but the test response was not valid JSON");
  }

  if (parsed.ok !== true) {
    throw new Error(`DeepSeek test response did not confirm ok=true for ${model}`);
  }

  return { ...parsed, model };
}

export function buildDeepSeekChatRequest({
  maxTokens = 1600,
  messages,
  model,
  thinkingEnabled,
}: {
  maxTokens?: number;
  messages: { role: "system" | "user"; content: string }[];
  model: DeepSeekModel;
  thinkingEnabled: boolean;
}) {
  return {
    extra_body: {
      thinking: { type: thinkingEnabled ? "enabled" : "disabled" },
    },
    max_tokens: maxTokens,
    messages,
    model,
    reasoning_effort: thinkingEnabled ? "high" : undefined,
    response_format: { type: "json_object" },
    temperature: thinkingEnabled ? undefined : 0.1,
  };
}

function normalizeDeepSeekOptions(
  options?: DeepSeekRequestOptions,
): DeepSeekRequestOptions | null {
  if (!options) return null;
  const apiKey = options.apiKey?.trim();
  const model = options.model || "deepseek-v4-flash";
  if (!apiKey && !options.baseURL && !options.thinkingEnabled && model === "deepseek-v4-flash") {
    return null;
  }

  return {
    apiKey,
    baseURL: options.baseURL?.trim() || undefined,
    model,
    thinkingEnabled: Boolean(options.thinkingEnabled),
  };
}

function resolveDeepSeekModel(value: string | undefined): DeepSeekModel {
  return DEEPSEEK_MODELS.includes(value as DeepSeekModel)
    ? (value as DeepSeekModel)
    : "deepseek-v4-flash";
}

export function stringifyChatMessageContent(content: unknown): string {
  if (typeof content === "string") {
    return content;
  }

  if (!Array.isArray(content)) {
    return "";
  }

  return content
    .map((part) => {
      if (typeof part === "string") return part;
      if (
        part &&
        typeof part === "object" &&
        "text" in part &&
        typeof part.text === "string"
      ) {
        return part.text;
      }
      return "";
    })
    .join("");
}

function buildLocalFallbackExtraction(text: string): ExtractionPayload {
  const possibleName =
    text.match(/(?:和|with|about)\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)/)?.[1] ||
    text.match(/([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)/)?.[1] ||
    "New friend";

  const likes = text.match(/喜欢([^，。,.;]+)/)?.[1]?.trim();
  const dueAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 3).toISOString();

  return {
    people: [
      {
        displayName: possibleName,
        relationLabel: "friend",
        updates: [
          {
            type: likes ? "PREFERENCE" : "PROFILE_FACT",
            fieldPath: likes ? "preferences.general" : "importantFacts",
            proposedValue: likes ? [likes] : [text.slice(0, 120)],
            summary: likes
              ? `${possibleName} likes ${likes}.`
              : `New memory about ${possibleName}.`,
            evidence: text.slice(0, 180),
            confidence: 0.55,
          },
        ],
      },
    ],
    reminders: text.includes("提醒")
      ? [
          {
            personName: possibleName,
            title: `Follow up with ${possibleName}`,
            dueAt,
            evidence: text.slice(0, 180),
            confidence: 0.5,
          },
        ]
      : [],
    giftIdeas: likes
      ? [
          {
            personName: possibleName,
            title: `${likes} related gift`,
            rationale: `The note says ${possibleName} likes ${likes}.`,
            priceBand: "$",
            sourceFacts: [`likes ${likes}`],
          },
        ]
      : [],
  };
}
