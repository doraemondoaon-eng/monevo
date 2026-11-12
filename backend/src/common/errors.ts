export type ErrorCode =
  | 'VALIDATION_ERROR'
  | 'BAD_REQUEST'
  | 'IMAGE_UPLOAD_FORBIDDEN'
  | 'BANK_CREDENTIAL_FORBIDDEN'
  | 'UNAUTHORIZED'
  | 'INVALID_CREDENTIALS'
  | 'TOKEN_EXPIRED'
  | 'INVALID_TOKEN'
  | 'REGISTRATION_CLOSED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'EMAIL_TAKEN'
  | 'ACCOUNT_HAS_TRANSACTIONS'
  | 'CATEGORY_IN_USE'
  | 'RATE_LIMITED'
  | 'INTERNAL_ERROR';

export interface ErrorDetail {
  path: string;
  message: string;
}

export class AppError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: ErrorCode,
    message: string,
    public readonly details?: ErrorDetail[],
  ) {
    super(message);
    this.name = 'AppError';
  }

  static badRequest(message: string, details?: ErrorDetail[]) {
    return new AppError(400, 'BAD_REQUEST', message, details);
  }
  static validation(message: string, details?: ErrorDetail[]) {
    return new AppError(400, 'VALIDATION_ERROR', message, details);
  }
  static unauthorized(code: ErrorCode = 'UNAUTHORIZED', message = 'Authentication required') {
    return new AppError(401, code, message);
  }
  static forbidden(code: ErrorCode = 'FORBIDDEN', message = 'Forbidden') {
    return new AppError(403, code, message);
  }
  static notFound(resource = 'Resource') {
    return new AppError(404, 'NOT_FOUND', `${resource} not found`);
  }
  static conflict(code: ErrorCode, message: string) {
    return new AppError(409, code, message);
  }
}

