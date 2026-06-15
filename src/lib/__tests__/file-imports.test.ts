import { describe, expect, it } from "vitest";

import {
  buildFileParseJobInputSummary,
  claimFileParseJob,
  parseFileParseJobInputSummary,
  normalizeExtractedText,
  parseUploadedFileId,
} from "@/lib/file-imports";

describe("file import worker helpers", () => {
  it("extracts uploaded file id from queued job summary", () => {
    expect(parseUploadedFileId("file_1:notes.txt:text/plain")).toBe("file_1");
  });

  it("round trips structured file parse job input summaries", () => {
    const summary = buildFileParseJobInputSummary({
      uploadedFileId: "file_1",
      filename: "notes.txt",
      contentType: "text/plain",
    });

    expect(parseFileParseJobInputSummary(summary)).toEqual({
      uploadedFileId: "file_1",
      filename: "notes.txt",
      contentType: "text/plain",
    });
    expect(parseUploadedFileId(summary)).toBe("file_1");
  });

  it("normalizes JSON text for reviewable imported memories", () => {
    expect(normalizeExtractedText('{"friend":"Alex"}', "application/json")).toBe(
      '{\n  "friend": "Alex"\n}',
    );
  });

  it("bounds plain text extraction output", () => {
    const text = "a".repeat(13_000);
    expect(normalizeExtractedText(text, "text/plain")).toHaveLength(12_000);
  });

  it("atomically claims a queued file parse job once", async () => {
    let status: "QUEUED" | "RUNNING" = "QUEUED";
    const operations = {
      claim: async () => {
        if (status !== "QUEUED") return 0;
        status = "RUNNING";
        return 1;
      },
      findClaimed: async (id: string) =>
        status === "RUNNING"
          ? { id, userId: "user_1", inputSummary: "file_1:note.txt:text/plain" }
          : null,
    };

    await expect(claimFileParseJob("job_1", operations)).resolves.toEqual({
      id: "job_1",
      userId: "user_1",
      inputSummary: "file_1:note.txt:text/plain",
    });
    await expect(claimFileParseJob("job_1", operations)).resolves.toBeNull();
  });
});
