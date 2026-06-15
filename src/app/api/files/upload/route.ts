import { del, put } from "@vercel/blob";

import { handleApiError, jsonOk, jsonError } from "@/lib/api";
import { runtimeFlags } from "@/lib/env";
import { buildFileParseJobInputSummary } from "@/lib/file-imports";
import { prisma } from "@/lib/db";
import { requireOwnedPersonId } from "@/lib/people";
import { requireCurrentUser } from "@/lib/session";
import {
  enforceUploadRateLimit,
  enforceUploadRequestSize,
  validateUploadFile,
} from "@/lib/uploads";

export async function POST(request: Request) {
  let uploadedBlobPathname: string | undefined;

  try {
    if (!runtimeFlags.hasBlobToken()) {
      return jsonError("File storage is not configured", 503);
    }

    const user = await requireCurrentUser();
    enforceUploadRequestSize(request.headers);
    const formData = await request.formData();
    const file = formData.get("file");
    const personId = formData.get("personId");

    if (!(file instanceof File)) {
      return jsonError("A file field is required", 422);
    }

    const ownedPersonId = await requireOwnedPersonId({
      userId: user.id,
      personId: typeof personId === "string" ? personId : undefined,
    });
    await enforceUploadRateLimit({ userId: user.id });
    const upload = validateUploadFile({ file, userId: user.id });

    const blob = await put(upload.pathname, file, {
      access: "private",
      addRandomSuffix: true,
      contentType: upload.contentType,
    });
    uploadedBlobPathname = blob.pathname;

    const { uploaded, parseJob } = await prisma
      .$transaction(async (tx) => {
        const uploadedFile = await tx.uploadedFile.create({
          data: {
            userId: user.id,
            personId: ownedPersonId,
            blobUrl: blob.url,
            pathname: blob.pathname,
            filename: upload.safeFilename,
            contentType: upload.contentType,
            size: upload.size,
            status: "UPLOADED",
          },
        });

        const job = await tx.aIJob.create({
          data: {
            userId: user.id,
            type: "FILE_PARSE",
            status: "QUEUED",
            inputSummary: buildFileParseJobInputSummary({
              uploadedFileId: uploadedFile.id,
              filename: upload.safeFilename,
              contentType: upload.contentType,
            }),
          },
        });

        await tx.auditEvent.create({
          data: {
            userId: user.id,
            action: "file.uploaded",
            entityType: "UploadedFile",
            entityId: uploadedFile.id,
            metadata: {
              aiJobId: job.id,
              contentType: upload.contentType,
              size: upload.size,
            },
          },
        });

        return { uploaded: uploadedFile, parseJob: job };
      })
      .catch(async (error) => {
        await cleanupUploadedBlob(uploadedBlobPathname);
        throw error;
      });

    return jsonOk({ file: uploaded, parseJob }, { status: 201 });
  } catch (error) {
    return handleApiError(error);
  }
}

async function cleanupUploadedBlob(pathname: string | undefined) {
  if (!pathname) return;

  try {
    await del(pathname, { token: process.env.BLOB_READ_WRITE_TOKEN });
  } catch (error) {
    console.error("[files/upload] Failed to clean up uploaded blob", error);
  }
}
