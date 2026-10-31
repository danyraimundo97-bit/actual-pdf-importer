import { NextFunction, Request, RequestHandler, Response } from 'express';
import multer from 'multer';
import { BatchTooLargeError, FileTooLargeError, formatBytes, ImporterError, TooManyFilesError } from './errors';

export interface UploadLimits {
  /** Per file. Generous for a bank statement, so a bad upload can't exhaust RAM. */
  maxFileBytes: number;
  /** Per request, all files together. */
  maxTotalBytes: number;
}

export const DEFAULT_UPLOAD_LIMITS: UploadLimits = {
  maxFileBytes: 20 * 1024 * 1024,
  maxTotalBytes: 50 * 1024 * 1024,
};

/**
 * Files past a route's limit are counted and drained rather than buffered,
 * so the error can say how many arrived. This caps how many busboy will even
 * look at, so a pathological request can't keep us counting forever.
 */
const HARD_MAX_FILES = 100;

export interface ReceiveFilesOptions {
  /** The multipart field name(s) the files may arrive under. */
  fields: string[];
  maxFiles: number;
  /** Appended to the TOO_MANY_FILES message, e.g. pointing at the batch route. */
  tooManyHint?: string;
  limits?: UploadLimits;
}

/**
 * Multer, plus the bookkeeping to tell the three upload failures apart and log
 * what actually arrived when one happens. Memory storage only: the PDF never
 * touches disk (privacy invariant, see CLAUDE.md).
 *
 * On success the files are in `req.files`, and with `maxFiles: 1` also in
 * `req.file`, so single-file routes read like they did with `upload.single`.
 * On failure it calls `next` with a typed ImporterError.
 */
export function receiveFiles({
  fields,
  maxFiles,
  tooManyHint,
  limits = DEFAULT_UPLOAD_LIMITS,
}: ReceiveFilesOptions): RequestHandler {
  return (req: Request, res: Response, next: NextFunction) => {
    const declaredBytes = parseContentLength(req.header('content-length'));
    let seenFiles = 0;

    /**
     * `stage` says how much of the body was read, which decides how exact the
     * logged count can be: none of it, part of it (multer aborted on the first
     * violation), or all of it.
     */
    const reject = (err: ImporterError, stage: 'unread' | 'aborted' | 'complete') => {
      const files = Array.isArray(req.files) ? req.files : [];
      const acceptedBytes = files.reduce((sum, f) => sum + f.size, 0);
      // Content-Length is the whole request as the client sent it, multipart
      // framing included; without it (chunked upload) only what was buffered
      // before the rejection is known.
      const size =
        declaredBytes !== undefined ? formatBytes(declaredBytes) : `at least ${formatBytes(acceptedBytes)}`;
      const count =
        stage === 'unread'
          ? 'an unknown number of file(s) (refused before reading)'
          : `${stage === 'aborted' ? 'at least ' : ''}${seenFiles} file(s)`;
      console.warn(
        `[upload] ${req.method} ${req.path} rejected with ${err.code}: received ${count}, ${size} in total ` +
          `(limits: ${maxFiles} file(s), ${formatBytes(limits.maxFileBytes)} per file, ` +
          `${formatBytes(limits.maxTotalBytes)} per request)`,
      );
      next(err);
    };

    // Refuse an oversized request before buffering any of it.
    if (declaredBytes !== undefined && declaredBytes > limits.maxTotalBytes) {
      return reject(new BatchTooLargeError(limits.maxTotalBytes, declaredBytes), 'unread');
    }

    const upload = multer({
      storage: multer.memoryStorage(),
      limits: { fileSize: limits.maxFileBytes, files: HARD_MAX_FILES },
      fileFilter: (_req, file, cb) => {
        if (!fields.includes(file.fieldname)) {
          return cb(new multer.MulterError('LIMIT_UNEXPECTED_FILE', file.fieldname));
        }
        seenFiles += 1;
        cb(null, seenFiles <= maxFiles);
      },
    }).any();

    upload(req, res, (err?: unknown) => {
      if (err instanceof multer.MulterError) {
        return reject(mapMulterError(err), 'aborted');
      }
      if (err) return next(err);

      if (seenFiles > maxFiles) {
        return reject(new TooManyFilesError(maxFiles, seenFiles, false, tooManyHint), 'complete');
      }

      // Only reachable without a Content-Length (chunked upload), since a
      // declared size over the limit was refused above.
      const files = Array.isArray(req.files) ? req.files : [];
      const totalBytes = files.reduce((sum, f) => sum + f.size, 0);
      if (totalBytes > limits.maxTotalBytes) {
        return reject(new BatchTooLargeError(limits.maxTotalBytes, totalBytes), 'complete');
      }

      if (maxFiles === 1) req.file = files[0];
      return next();
    });

    function mapMulterError(err: multer.MulterError): ImporterError {
      switch (err.code) {
        case 'LIMIT_FILE_SIZE':
          return new FileTooLargeError(limits.maxFileBytes);
        case 'LIMIT_FILE_COUNT':
          return new TooManyFilesError(maxFiles, HARD_MAX_FILES, true, tooManyHint);
        case 'LIMIT_UNEXPECTED_FILE':
          return new ImporterError(
            'MISSING_FIELD',
            `Unexpected file field "${err.field}". This route expects files under ${fields.map((f) => `"${f}"`).join(' or ')}.`,
            400,
          );
        default:
          return new ImporterError('MISSING_FIELD', `Malformed upload: ${err.message}.`, 400);
      }
    }
  };
}

function parseContentLength(header: string | undefined): number | undefined {
  if (!header) return undefined;
  const n = Number(header);
  return Number.isSafeInteger(n) && n >= 0 ? n : undefined;
}
