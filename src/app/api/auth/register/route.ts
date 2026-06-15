import { z } from "zod";

import { handleApiError, jsonError, jsonOk } from "@/lib/api";
import { prisma } from "@/lib/db";
import { runtimeFlags } from "@/lib/env";
import { hashPassword, normalizeEmail } from "@/lib/password";
import { assertRequestRateLimit } from "@/lib/rate-limit";

const registerSchema = z.object({
  name: z.string().trim().max(80).optional(),
  email: z.string().email(),
  password: z.string().min(8),
});

export async function POST(request: Request) {
  try {
    assertRequestRateLimit({
      request,
      scope: "auth-register",
      limit: 5,
      windowMs: 60 * 60 * 1000,
    });

    if (!runtimeFlags.hasPasswordAuth()) {
      return jsonError(
        "账号注册需要先配置 DATABASE_URL，以及 NEXTAUTH_SECRET 或 AUTH_SECRET。",
        503,
      );
    }

    const parsed = registerSchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) {
      return jsonError("Use a valid email and a password with at least 8 characters.", 400);
    }

    const email = normalizeEmail(parsed.data.email);
    const existing = await prisma.user.findUnique({ where: { email } });

    if (existing) {
      return jsonError("This email already has a Memoria account.", 409);
    }

    const user = await prisma.user.create({
      data: {
        email,
        name: parsed.data.name?.trim() || email.split("@")[0],
        passwordHash: hashPassword(parsed.data.password),
      },
      select: {
        id: true,
        email: true,
        name: true,
      },
    });

    return jsonOk({ user }, { status: 201 });
  } catch (error) {
    return handleApiError(error);
  }
}
