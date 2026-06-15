import { handleApiError, jsonOk } from "@/lib/api";
import { getDashboardData } from "@/lib/friend-memory";
import { requireCurrentUser } from "@/lib/session";

export async function GET(request: Request) {
  try {
    const user = await requireCurrentUser();
    const url = new URL(request.url);
    const from = parseDateParam(url.searchParams.get("from"));
    const to = parseDateParam(url.searchParams.get("to"));
    const groupId = url.searchParams.get("groupId");
    const type = url.searchParams.get("type");
    const dashboard = await getDashboardData(user.id);
    const groupPeople = groupId
      ? new Set(
          dashboard.people
            .filter((person) => person.groupIds.includes(groupId))
            .map((person) => person.displayName),
        )
      : null;

    const events = dashboard.calendarEvents.filter((event) => {
      const eventDate = new Date(event.date);
      if (from && eventDate < from) return false;
      if (to && eventDate > to) return false;
      if (type && event.type !== type) return false;
      if (groupPeople && !groupPeople.has(event.personName)) return false;
      return true;
    });

    return jsonOk({ events });
  } catch (error) {
    return handleApiError(error);
  }
}

function parseDateParam(value: string | null) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}
