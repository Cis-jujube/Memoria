import { randomUUID } from "node:crypto";

import { publicApiError } from "@/lib/api";
import { prisma } from "@/lib/db";

const DEFAULT_MAX_UPLOAD_BYTES = 10 * 1024 * 1024;
const DEFAULT_MAX_UPLOAD_REQUEST_BYTES = DEFAULT_MAX_UPLOAD_BYTES + 1024 * 1024;
const DEFAULT_UPLOADS_PER_HOUR = 25;

const allowedContentTypes = new Set([
  "application/json",
  "application/pdf",
  "image/heic",
  "image/heif",
  "image/jpeg",
  "image/png",
  "image/webp",
  "text/csv",
  "text/markdown",
  "text/plain",
]);

const allowedExtensions = new Set([
  ".csv",
  ".heic",
  ".heif",
  ".jpeg",
  ".jpg",
  ".json",
  ".md",
  ".pdf",
  ".png",
  ".txt",
  ".webp",
]);

export type ValidatedUpload = {
  safeFilename: string;
  pathname: string;
  contentType: string;
  size: number;
};

export function enforceUploadRequestSize(headers: Headers) {
  const rawLength = headers.get("content-length")?.trim();
  if (!rawLength) return;

  const contentLength = Number.parseInt(rawLength, 10);
  if (!Number.isFinite(contentLength) || contentLength < 0) return;

  const maxRequestBytes = readPositiveIntEnv(
    "UPLOAD_MAX_REQUEST_BYTES",
    DEFAULT_MAX_UPLOAD_REQUEST_BYTES,
  );

  if (contentLength > maxRequestBytes) {
    throw publicApiError("Upload request is too large", 413);
  }
}

export function validateUploadFile({
  file,
  userId,
  now = Date.now(),
}: {
  file: File;
  userId: string;
  now?: number;
}): ValidatedUpload {
  const maxBytes = readPositiveIntEnv(
    "UPLOAD_MAX_BYTES",
    DEFAULT_MAX_UPLOAD_BYTES,
  );

  if (file.size <= 0) {
    throw publicApiError("File is empty", 422);
  }

  if (file.size > maxBytes) {
    throw publicApiError("File is too large", 413);
  }

  const safeFilename = sanitizeUploadFilename(file.name);
  const extension = extensionFor(safeFilename);
  const contentType = file.type || "application/octet-stream";

  if (!allowedExtensions.has(extension)) {
    throw publicApiError("File type is not supported", 415);
  }

  if (file.type && !allowedContentTypes.has(file.type)) {
    throw publicApiError("File content type is not supported", 415);
  }

  return {
    safeFilename,
    pathname: `${userId}/uploads/${now}-${randomUUID()}-${safeFilename}`,
    contentType,
    size: file.size,
  };
}

export function sanitizeUploadFilename(filename: string) {
  const basename = filename.split(/[\\/]/).pop()?.trim() || "upload";
  const sanitized = basename
    .normalize("NFKD")
    .replace(/[^\w.-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 96);

  return sanitized || "upload";
}

export async function enforceUploadRateLimit({
  userId,
  now = new Date(),
}: {
  userId: string;
  now?: Date;
}) {
  const limit = readPositiveIntEnv(
    "UPLOAD_RATE_LIMIT_PER_HOUR",
    DEFAULT_UPLOADS_PER_HOUR,
  );
  const windowStart = new Date(now.getTime() - 60 * 60 * 1000);
  const recentUploads = await prisma.uploadedFile.count({
    where: {
      userId,
      createdAt: { gte: windowStart },
    },
  });

  if (recentUploads >= limit) {
    throw publicApiError("Upload rate limit exceeded", 429);
  }
}

function extensionFor(filename: string) {
  const lastDot = filename.lastIndexOf(".");
  return lastDot >= 0 ? filename.slice(lastDot).toLowerCase() : "";
}

function readPositiveIntEnv(name: string, fallback: number) {
  const rawValue = process.env[name]?.trim();
  if (!rawValue) return fallback;

  const parsed = Number.parseInt(rawValue, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}
