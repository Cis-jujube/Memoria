import { ZodError } from "zod";

export class PublicApiError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "PublicApiError";
    this.status = status;
  }
}

export function publicApiError(message: string, status = 400): PublicApiError {
  return new PublicApiError(message, status);
}

export function jsonOk<T>(data: T, init?: ResponseInit) {
  return Response.json(data, init);
}

export function jsonError(message: string, status = 400) {
  return Response.json({ error: message }, { status });
}

export function handleApiError(error: unknown) {
  if (error instanceof Response) {
    return error;
  }
  if (error instanceof PublicApiError) {
    return jsonError(error.message, error.status);
  }
  if (error instanceof ZodError) {
    return jsonError("Invalid request", 422);
  }
  if (error instanceof Error) {
    console.error("[api]", error);
    const isConfigurationError =
      error.message.includes("not configured") ||
      error.message.includes("API_KEY is required") ||
      error.message.includes("Unsupported AI_PROVIDER");

    return jsonError(
      isConfigurationError
        ? "A required server service is not configured"
        : "Unexpected server error",
      isConfigurationError ? 503 : 500,
    );
  }
  return jsonError("Unexpected server error", 500);
}
