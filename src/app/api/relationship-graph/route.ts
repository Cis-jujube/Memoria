import { handleApiError, jsonOk } from "@/lib/api";
import { getDashboardData } from "@/lib/friend-memory";
import { buildRelationshipGraph } from "@/lib/relationship-intelligence";
import { requireCurrentUser } from "@/lib/session";

export async function GET() {
  try {
    const user = await requireCurrentUser();
    const dashboard = await getDashboardData(user.id);
    const graph = buildRelationshipGraph(dashboard, {
      id: user.id,
      name: user.name,
      email: user.email,
      scores: dashboard.relationshipScores,
    });

    return jsonOk({ graph });
  } catch (error) {
    return handleApiError(error);
  }
}
