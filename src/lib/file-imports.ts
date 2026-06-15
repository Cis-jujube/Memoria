import { get } from "@vercel/blob";

import { prisma } from "@/lib/db";

const TEXT_PARSE_CONTENT_TYPES = new Set([
  "application/json",
  "text/csv",
  "text/markdown",
  "text/plain",
]);

const MAX_PARSE_BYTES = 512 * 1024;
const MAX_EXTRACTED_CHARS = 12_000;

export type FileParseResult = {
  jobId: string;
  status: "SUCCEEDED" | "FAILED" | "SKIPPED";
  uploadedFileId?: string;
  error?: string;
};

export type ClaimedFileParseJob = {
  id: string;
  userId: string;
  inputSummary: string;
};

export type FileParseJobClaimOperations = {
  claim: (jobId: string) => Promise<number>;
  findClaimed: (jobId: string) => Promise<ClaimedFileParseJob | null>;
};

export type FileParseJobInputSummary = {
  uploadedFileId: string;
  filename?: string;
  contentType?: string;
};

export async function processQueuedFileParseJobs(limit = 5) {
  const jobs = await prisma.aIJob.findMany({
    where: { type: "FILE_PARSE", status: "QUEUED" },
    orderBy: { createdAt: "asc" },
    take: limit,
  });

  const results: FileParseResult[] = [];

  for (const job of jobs) {
    results.push(await processFileParseJob(job.id));
  }

  return results;
}

export async function processFileParseJob(jobId: string): Promise<FileParseResult> {
  const job = await claimFileParseJob(jobId);

  if (!job) {
    return { jobId, status: "SKIPPED", error: "Job was not claimable" };
  }

  const uploadedFileId = parseUploadedFileId(job.inputSummary);

  try {
    const uploadedFile = uploadedFileId
      ? await prisma.uploadedFile.findFirst({
          where: { id: uploadedFileId, userId: job.userId },
        })
      : null;

    if (!uploadedFile) {
      throw new Error("Uploaded file was not found");
    }

    if (!TEXT_PARSE_CONTENT_TYPES.has(uploadedFile.contentType)) {
      throw new Error(`Unsupported parser for ${uploadedFile.contentType}`);
    }

    if (uploadedFile.size > MAX_PARSE_BYTES) {
      throw new Error("File is too large for inline text parsing");
    }

    const blob = await get(uploadedFile.pathname, {
      access: "private",
      token: process.env.BLOB_READ_WRITE_TOKEN,
      useCache: false,
    });

    if (!blob || blob.statusCode !== 200 || !blob.stream) {
      throw new Error("Blob content was not found");
    }

    const extractedText = await readTextStream(blob.stream, MAX_EXTRACTED_CHARS);
    const normalizedText = normalizeExtractedText(
      extractedText,
      uploadedFile.contentType,
    );

    if (!normalizedText) {
      throw new Error("No text could be extracted");
    }

    const { memory, pendingUpdate } = await prisma.$transaction(async (tx) => {
      const memoryRecord = await tx.memory.create({
        data: {
          userId: job.userId,
          personId: uploadedFile.personId,
          title: `Import: ${uploadedFile.filename}`,
          body: normalizedText,
          sourceType: "file_import",
          sourceId: uploadedFile.id,
          confidence: 0.65,
        },
      });

      const pending = await tx.pendingUpdate.create({
        data: {
          userId: job.userId,
          personId: uploadedFile.personId,
          type: "FILE_NOTE",
          fieldPath: "memories.importedFile",
          proposedValue: {
            memoryId: memoryRecord.id,
            filename: uploadedFile.filename,
          },
          summary: `Review imported notes from ${uploadedFile.filename}`,
          evidence: normalizedText.slice(0, 600),
          sourceType: "file_import",
          sourceId: uploadedFile.id,
          confidence: 0.65,
        },
      });

      await tx.uploadedFile.update({
        where: { id: uploadedFile.id },
        data: {
          status: "READY",
          extractedText: normalizedText,
          parseError: null,
        },
      });

      await tx.auditEvent.create({
        data: {
          userId: job.userId,
          action: "file.parsed",
          entityType: "UploadedFile",
          entityId: uploadedFile.id,
          metadata: {
            aiJobId: job.id,
            memoryId: memoryRecord.id,
            pendingUpdateId: pending.id,
          },
        },
      });

      return { memory: memoryRecord, pendingUpdate: pending };
    });

    await prisma.aIJob.update({
      where: { id: job.id },
      data: {
        status: "SUCCEEDED",
        output: {
          uploadedFileId: uploadedFile.id,
          memoryId: memory.id,
          pendingUpdateId: pendingUpdate.id,
          extractedChars: normalizedText.length,
        },
      },
    });

    return { jobId: job.id, uploadedFileId: uploadedFile.id, status: "SUCCEEDED" };
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "File parse failed unexpectedly";

    if (uploadedFileId) {
      await prisma.uploadedFile.updateMany({
        where: { id: uploadedFileId, userId: job.userId },
        data: { status: "FAILED", parseError: message },
      });
    }

    await prisma.aIJob.update({
      where: { id: job.id },
      data: {
        status: "FAILED",
        error: message,
      },
    });

    return {
      jobId: job.id,
      uploadedFileId,
      status: "FAILED",
      error: message,
    };
  }
}

export async function claimFileParseJob(
  jobId: string,
  operations: FileParseJobClaimOperations = {
    claim: async (id) => {
      const result = await prisma.aIJob.updateMany({
        where: { id, type: "FILE_PARSE", status: "QUEUED" },
        data: { status: "RUNNING" },
      });
      return result.count;
    },
    findClaimed: async (id) =>
      prisma.aIJob.findFirst({
        where: { id, type: "FILE_PARSE", status: "RUNNING" },
        select: { id: true, userId: true, inputSummary: true },
      }),
  },
) {
  const claimedCount = await operations.claim(jobId);

  if (claimedCount !== 1) {
    return null;
  }

  return operations.findClaimed(jobId);
}

export function parseUploadedFileId(inputSummary: string) {
  return parseFileParseJobInputSummary(inputSummary).uploadedFileId;
}

export function buildFileParseJobInputSummary({
  uploadedFileId,
  filename,
  contentType,
}: FileParseJobInputSummary) {
  return JSON.stringify({ uploadedFileId, filename, contentType });
}

export function parseFileParseJobInputSummary(
  inputSummary: string,
): FileParseJobInputSummary {
  try {
    const parsed = JSON.parse(inputSummary) as Partial<FileParseJobInputSummary>;
    if (typeof parsed.uploadedFileId === "string") {
      return {
        uploadedFileId: parsed.uploadedFileId,
        filename:
          typeof parsed.filename === "string" ? parsed.filename : undefined,
        contentType:
          typeof parsed.contentType === "string" ? parsed.contentType : undefined,
      };
    }
  } catch {
    // Older queued jobs used "uploadedFileId:filename:contentType".
  }

  return { uploadedFileId: inputSummary.split(":")[0]?.trim() || "" };
}

export function normalizeExtractedText(text: string, contentType: string) {
  const trimmed = text.trim();

  if (!trimmed) return "";

  if (contentType === "application/json") {
    try {
      return JSON.stringify(JSON.parse(trimmed), null, 2).slice(
        0,
        MAX_EXTRACTED_CHARS,
      );
    } catch {
      return trimmed.slice(0, MAX_EXTRACTED_CHARS);
    }
  }

  return trimmed.replace(/\s+\n/g, "\n").slice(0, MAX_EXTRACTED_CHARS);
}

async function readTextStream(
  stream: ReadableStream<Uint8Array>,
  maxChars: number,
) {
  const reader = stream.getReader();
  const decoder = new TextDecoder();
  let output = "";

  while (output.length < maxChars) {
    const { done, value } = await reader.read();
    if (done) break;
    output += decoder.decode(value, { stream: true });
  }

  output += decoder.decode();
  return output.slice(0, maxChars);
}
