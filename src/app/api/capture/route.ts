import { z } from "zod";

import { DEEPSEEK_MODELS } from "@/lib/ai";
import { handleApiError, jsonOk } from "@/lib/api";
import { captureNaturalLanguageMemory } from "@/lib/friend-memory";
import { assertRequestRateLimit } from "@/lib/rate-limit";
import { requireCurrentUser } from "@/lib/session";

const captureSchema = z.object({
  deepSeek: z.object({
    apiKey: z.string().trim().min(8).max(512),
    model: z.enum(DEEPSEEK_MODELS).default("deepseek-v4-flash"),
    thinkingEnabled: z.boolean().default(false),
  }).optional(),
  text: z.string().trim().min(3).max(5000),
});

export async function POST(request: Request) {
  try {
    const user = await requireCurrentUser();
    assertRequestRateLimit({
      request,
      scope: "capture",
      userId: user.id,
      limit: 30,
      windowMs: 60 * 1000,
    });
    const body = captureSchema.parse(await request.json());
    const result = await captureNaturalLanguageMemory({
      deepSeek: body.deepSeek,
      userId: user.id,
      text: body.text,
    });

    return jsonOk({
      memoryId: result.memory.id,
      pendingUpdateCount: result.pendingUpdates.length,
    });
  } catch (error) {
    return handleApiError(error);
  }
}
