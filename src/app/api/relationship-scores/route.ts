import { handleApiError, jsonOk } from "@/lib/api";
import { getDashboardData } from "@/lib/friend-memory";
import { requireCurrentUser } from "@/lib/session";

export async function GET() {
  try {
    const user = await requireCurrentUser();
    const dashboard = await getDashboardData(user.id);
    return jsonOk({ scores: dashboard.relationshipScores });
  } catch (error) {
    return handleApiError(error);
  }
}
