import { getServerSession } from "next-auth";

import { authOptions } from "@/lib/auth";
import { runtimeFlags } from "@/lib/env";

export async function getCurrentUser() {
  if (!runtimeFlags.hasAuthSecret()) {
    return null;
  }

  const session = await getServerSession(authOptions);
  return session?.user || null;
}

export async function requireCurrentUser() {
  const user = await getCurrentUser();
  if (!user?.id) {
    throw new Response("Unauthorized", { status: 401 });
  }
  return user;
}
