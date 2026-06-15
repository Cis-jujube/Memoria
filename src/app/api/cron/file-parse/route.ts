import { handleApiError, jsonError, jsonOk } from "@/lib/api";
import { requireEnv } from "@/lib/env";
import { processQueuedFileParseJobs } from "@/lib/file-imports";

function isAuthorized(request: Request) {
  const expected = requireEnv("CRON_SECRET");
  return request.headers.get("authorization") === `Bearer ${expected}`;
}

export async function GET(request: Request) {
  try {
    if (!isAuthorized(request)) {
      return jsonError("Unauthorized", 401);
    }

    const results = await processQueuedFileParseJobs();
    return jsonOk({ processed: results.length, results });
  } catch (error) {
    return handleApiError(error);
  }
}

export const POST = GET;
