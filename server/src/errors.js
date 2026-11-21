export class ApiError extends Error {
  constructor(status, code, message, fields) {
    super(message);
    this.status = status;
    this.code = code;
    this.fields = fields; // optional {field: message} for form validation
  }
}

export const notFound = (what) => new ApiError(404, 'not_found', `${what} not found`);
export const badRequest = (message) => new ApiError(400, 'bad_request', message);

// Single error handler: {error:{code,message,fields?}} with 400/404/500/503.
export function errorHandler(err, req, res, _next) {
  if (err instanceof ApiError) {
    const { status, code, message, fields } = err;
    return res.status(status).json({ error: { code, message, ...(fields ? { fields } : {}) } });
  }
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: { code: 'bad_request', message: 'Body is not valid JSON' } });
  }
  console.error(`[error] ${req.method} ${req.path}:`, err.message);
  res.status(500).json({ error: { code: 'internal', message: 'Something went wrong' } });
}
