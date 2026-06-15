import { z } from "zod";

import { DEEPSEEK_MODELS, testDeepSeekConnection } from "@/lib/ai";
import { handleApiError, jsonError, jsonOk, publicApiError } from "@/lib/api";
import { assertRequestRateLimit } from "@/lib/rate-limit";
import { requireCurrentUser } from "@/lib/session";

const deepSeekTestSchema = z.object({
  apiKey: z.string().trim().min(8).max(512),
  model: z.enum(DEEPSEEK_MODELS).default("deepseek-v4-flash"),
  thinkingEnabled: z.boolean().default(false),
});

export async function POST(request: Request) {
  try {
    const user = await requireCurrentUser();
    assertRequestRateLimit({
      request,
      scope: "deepseek-test",
      userId: user.id,
      limit: 6,
      windowMs: 5 * 60 * 1000,
    });

    const parsed = deepSeekTestSchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) {
      throw publicApiError("请先填入有效的 DeepSeek API key。", 422);
    }

    const result = await testDeepSeekConnection(parsed.data);
    return jsonOk({
      ok: true,
      model: result.model,
      service: result.service,
      thinking: parsed.data.thinkingEnabled ? "enabled" : "disabled",
    });
  } catch (error) {
    if (error instanceof Response || error instanceof Error && "status" in error) {
      return handleApiError(error);
    }

    return jsonError(
      "DeepSeek 连接没有通过。请检查 API key、模型权限、余额和网络。",
      400,
    );
  }
}
