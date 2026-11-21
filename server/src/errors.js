export class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export const notFound = (what) => new ApiError(404, 'not_found', `${what} not found`);
export const badRequest = (message) => new ApiError(400, 'bad_request', message);

// Single error handler: {error:{code,message}} with 400/404/500.
export function errorHandler(err, req, res, _next) {
  if (err instanceof ApiError) {
    return res.status(err.status).json({ error: { code: err.code, message: err.message } });
  }
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: { code: 'bad_request', message: 'Body is not valid JSON' } });
  }
  console.error(`[error] ${req.method} ${req.path}:`, err.message);
  res.status(500).json({ error: { code: 'internal', message: 'Something went wrong' } });
}
