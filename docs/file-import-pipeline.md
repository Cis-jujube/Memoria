# File Import Pipeline

Memoria treats file ingestion as a staged workflow. Uploading a file does not directly mutate people, memories, or profile facts.

## Upload Guardrails

`POST /api/files/upload` enforces:

- authenticated user session;
- optional `personId` ownership check against the active user;
- request-level `Content-Length` limit via `UPLOAD_MAX_REQUEST_BYTES` before multipart parsing;
- maximum size via `UPLOAD_MAX_BYTES` with a 10 MB default;
- supported extensions: `.csv`, `.heic`, `.heif`, `.jpeg`, `.jpg`, `.json`, `.md`, `.pdf`, `.png`, `.txt`, `.webp`;
- supported MIME types for PDF, common images, JSON, CSV, Markdown, and plain text;
- sanitized storage basename;
- per-user hourly rate limit via `UPLOAD_RATE_LIMIT_PER_HOUR` with a default of 25.

## Lifecycle

1. Validate request.
2. Write the private object to Vercel Blob.
3. Create `UploadedFile(status=UPLOADED)`.
4. Create `AIJob(type=FILE_PARSE, status=QUEUED)`.
5. Write an audit event.

The cron route `GET|POST /api/cron/file-parse` is protected by `Authorization: Bearer $CRON_SECRET`. It claims queued `FILE_PARSE` jobs, extracts bounded text for JSON, Markdown, CSV, and plain text files, creates a source `Memory`, creates a `FILE_NOTE` pending update, and marks the file `READY`. Unsupported formats such as PDF and images are marked `FAILED` until a separate OCR/parser worker is added.

## Security Boundary

Untrusted file bytes are not parsed inside the upload request. The parser route reads private blobs server-side, caps inline parsing at 512 KB / 12,000 characters, and never mutates profile facts directly. Profile changes still require pending-update confirmation.
