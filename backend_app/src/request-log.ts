import crypto from 'crypto';
import { NextFunction, Request, Response } from 'express';
import { Logger } from 'pino';
import { logger as rootLogger } from './logger';

export const REQUEST_ID_HEADER = 'X-Request-Id';

/** Ids the app sends are 16 hex chars; accept anything short and plain. */
const VALID_ID = /^[A-Za-z0-9_-]{1,64}$/;

/** The request-scoped logger set up by `requestLogger`, or the root one. */
export function requestLog(res: Response): Logger {
  return (res.locals.log as Logger | undefined) ?? rootLogger.child({ area: 'http' });
}

/**
 * The path as it may be logged: the route pattern when one matched
 * (`/categories/:payee`, so a payee in the URL never reaches an info line),
 * otherwise the bare path. Never the query string.
 */
export function loggablePath(req: Request): string {
  const routePath = req.route?.path;
  return typeof routePath === 'string' ? `${req.baseUrl}${routePath}` : req.path;
}

/**
 * Gives every request an id (the app's `X-Request-Id`, or a new one),
 * echoes it back, and writes one info line when the response is sent:
 * method, path, status, duration and id. Mounted before auth, so rejected
 * requests are logged too. Never logs headers or bodies.
 */
export function requestLogger(base: Logger = rootLogger) {
  return (req: Request, res: Response, next: NextFunction) => {
    const header = req.header(REQUEST_ID_HEADER);
    const id = header && VALID_ID.test(header) ? header : crypto.randomBytes(8).toString('hex');
    const started = process.hrtime.bigint();
    res.locals.requestId = id;
    res.locals.log = base.child({ area: 'http', req: id });
    res.setHeader(REQUEST_ID_HEADER, id);
    res.on('finish', () => {
      const ms = Number((process.hrtime.bigint() - started) / 1_000_000n);
      requestLog(res).info(
        { method: req.method, path: loggablePath(req), status: res.statusCode, ms },
        `${req.method} ${loggablePath(req)} ${res.statusCode} ${ms}ms`,
      );
    });
    next();
  };
}
