import { z } from "zod";

import { DEEPSEEK_MODELS, extractFriendMemory, resolveAIProvider } from "@/lib/ai";
import { handleApiError, jsonOk } from "@/lib/api";
import { assertRequestRateLimit } from "@/lib/rate-limit";
import { requireCurrentUser } from "@/lib/session";

const extractionRequestSchema = z.object({
  deepSeek: z.object({
    apiKey: z.string().trim().min(8).max(512),
    model: z.enum(DEEPSEEK_MODELS).default("deepseek-v4-flash"),
    thinkingEnabled: z.boolean().default(false),
  }).optional(),
  text: z.string().trim().min(3).max(5000),
  locale: z.string().trim().min(2).max(32).optional(),
  timezone: z.string().trim().min(1).max(64).optional(),
});

export async function POST(request: Request) {
  try {
    const user = await requireCurrentUser();
    assertRequestRateLimit({
      request,
      scope: "ai-extract",
      userId: user.id,
      limit: 20,
      windowMs: 60 * 1000,
    });
    const body = extractionRequestSchema.parse(await request.json());
    const extraction = await extractFriendMemory({
      text: body.text,
      locale: body.locale,
      timezone: body.timezone,
    }, {
      deepSeek: body.deepSeek,
    });

    return jsonOk({
      provider: body.deepSeek ? "deepseek" : resolveAIProvider(),
      extraction,
      writesDatabase: false,
    });
  } catch (error) {
    return handleApiError(error);
  }
}
