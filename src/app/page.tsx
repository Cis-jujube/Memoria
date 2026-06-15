import { FriendCommandCenter } from "@/components/app/friend-command-center";
import { getDashboardData } from "@/lib/friend-memory";
import { runtimeFlags } from "@/lib/env";
import { getCurrentUser } from "@/lib/session";

export const dynamic = "force-dynamic";

export default async function Home() {
  const user = await getCurrentUser();
  const data = await getDashboardData(
    user?.id,
    user?.name || user?.email?.split("@")[0] || undefined,
  );

  return (
    <FriendCommandCenter
      data={data}
      isAuthenticated={Boolean(user?.id)}
      hasGoogleAuth={runtimeFlags.hasGoogleAuth() && runtimeFlags.hasAuthSecret()}
      hasPasswordAuth={runtimeFlags.hasPasswordAuth()}
      hasDatabaseUrl={runtimeFlags.hasDatabaseUrl()}
      hasAuthSecret={runtimeFlags.hasAuthSecret()}
      userEmail={user?.email}
      userName={user?.name}
    />
  );
}
