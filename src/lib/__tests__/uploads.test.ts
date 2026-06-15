import { describe, expect, it } from "vitest";

import {
  enforceUploadRequestSize,
  sanitizeUploadFilename,
  validateUploadFile,
} from "@/lib/uploads";

describe("upload validation", () => {
  it("sanitizes path-like filenames before blob storage", () => {
    expect(sanitizeUploadFilename("../../May Zhang notes.pdf")).toBe(
      "May-Zhang-notes.pdf",
    );
  });

  it("accepts supported small files and builds a user-scoped pathname", () => {
    const file = new File(["hello"], "chat.json", {
      type: "application/json",
    });

    const upload = validateUploadFile({
      file,
      userId: "user_1",
      now: 1781110000000,
    });

    expect(upload.safeFilename).toBe("chat.json");
    expect(upload.pathname).toContain("user_1/uploads/1781110000000-");
    expect(upload.pathname).toContain("-chat.json");
  });

  it("rejects unsupported file extensions", () => {
    const file = new File(["binary"], "archive.zip", {
      type: "application/zip",
    });

    expect(() => validateUploadFile({ file, userId: "user_1" })).toThrow(
      "File type is not supported",
    );
  });

  it("rejects oversized files", () => {
    const previous = process.env.UPLOAD_MAX_BYTES;
    process.env.UPLOAD_MAX_BYTES = "4";
    const file = new File(["12345"], "note.txt", { type: "text/plain" });

    expect(() => validateUploadFile({ file, userId: "user_1" })).toThrow(
      "File is too large",
    );

    if (previous === undefined) {
      delete process.env.UPLOAD_MAX_BYTES;
    } else {
      process.env.UPLOAD_MAX_BYTES = previous;
    }
  });

  it("rejects oversized upload requests before multipart parsing", () => {
    const previous = process.env.UPLOAD_MAX_REQUEST_BYTES;
    process.env.UPLOAD_MAX_REQUEST_BYTES = "10";

    expect(() =>
      enforceUploadRequestSize(new Headers({ "content-length": "11" })),
    ).toThrow("Upload request is too large");
    expect(() =>
      enforceUploadRequestSize(new Headers({ "content-length": "10" })),
    ).not.toThrow();

    if (previous === undefined) {
      delete process.env.UPLOAD_MAX_REQUEST_BYTES;
    } else {
      process.env.UPLOAD_MAX_REQUEST_BYTES = previous;
    }
  });
});
