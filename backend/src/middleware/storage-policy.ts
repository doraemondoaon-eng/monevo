import type { FastifyInstance, FastifyRequest } from 'fastify';
import { AppError } from '../common/errors.js';

/**
 * Section 3.2 Critical Data Storage Policy:
 * Strictly forbids uploading slip images, receipts, payment proofs, documents,
 * or Base64-encoded images to the server or PostgreSQL.
 */
const FORBIDDEN_IMAGE_FIELD_NAMES = new Set([
  'image',
  'images',
  'photo',
  'photos',
  'slip',
  'receipt',
  'attachment',
  'attachments',
  'document',
  'proof',
  'file',
  'base64',
  'imagebase64',
  'receiptimage',
  'slipimage',
  'backupfile',
  'backuparchive',
  'monevobackup',
]);

/**
 * Section 11 Security Policy:
 * Strictly forbids storing bank passwords, bank PINs, card CVV/PINs, or full
 * unmasked bank account numbers on the server. Only `accountNumberLast4` is allowed.
 */
const FORBIDDEN_BANK_SECRET_FIELD_NAMES = new Set([
  'bankpassword',
  'bankpin',
  'cardpin',
  'cvv',
  'cvc',
  'fullaccountnumber',
  'accountnumber',
  'cardnumber',
]);

const DATA_URI_PATTERN = /data:\s*(?:image|application\/pdf|application\/octet-stream)[^;]*;base64,/i;
// Detects long contiguous base64-encoded chunks (>= 256 chars without whitespace)
const LONG_BASE64_BLOB_PATTERN = /[A-Za-z0-9+/=_-]{256,}/;

function inspectValueForProhibitedMedia(value: unknown, path = ''): void {
  if (typeof value === 'string') {
    if (DATA_URI_PATTERN.test(value) || LONG_BASE64_BLOB_PATTERN.test(value)) {
      throw new AppError(
        400,
        'IMAGE_UPLOAD_FORBIDDEN',
        'Critical Data Storage Policy (3.2): Uploading images, payment slips, receipts, or Base64 data to the server is strictly prohibited. Store transaction images in Local Application Storage on the device only.',
        path ? [{ path, message: 'Contains prohibited image or Base64 payload' }] : undefined,
      );
    }
    return;
  }

  if (Array.isArray(value)) {
    for (let i = 0; i < value.length; i++) {
      inspectValueForProhibitedMedia(value[i], `${path}[${i}]`);
    }
    return;
  }

  if (value !== null && typeof value === 'object') {
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      const normalized = k.toLowerCase().replace(/[_-]/g, '');
      const nextPath = path ? `${path}.${k}` : k;
      if (FORBIDDEN_IMAGE_FIELD_NAMES.has(normalized)) {
        throw new AppError(
          400,
          'IMAGE_UPLOAD_FORBIDDEN',
          `Field "${k}" is prohibited by Critical Data Storage Policy (3.2). Transaction images must be stored locally on the device only.`,
          [{ path: nextPath, message: 'Image/attachment upload to server is forbidden' }],
        );
      }
      if (FORBIDDEN_BANK_SECRET_FIELD_NAMES.has(normalized)) {
        throw new AppError(
          400,
          'BANK_CREDENTIAL_FORBIDDEN',
          `Field "${k}" is prohibited by Security Policy (Section 11). Never store bank passwords, PINs, or full unmasked account numbers; use accountNumberLast4 only.`,
          [{ path: nextPath, message: 'Bank credentials and full account numbers are forbidden' }],
        );
      }
      inspectValueForProhibitedMedia(v, nextPath);
    }
  }
}

export function registerStoragePolicyEnforcement(app: FastifyInstance): void {
  // Reject multipart/form-data, image/*, and binary uploads before parsing
  app.addHook('onRequest', async (req: FastifyRequest) => {
    const contentType = (req.headers['content-type'] ?? '').toLowerCase();
    if (
      contentType.startsWith('multipart/') ||
      contentType.startsWith('image/') ||
      contentType.startsWith('application/octet-stream') ||
      contentType.startsWith('application/zip') ||
      contentType.startsWith('application/x-zip')
    ) {
      throw new AppError(
        400,
        'IMAGE_UPLOAD_FORBIDDEN',
        'Critical Data Storage Policy (3.2): Binary or multipart file uploads are strictly prohibited on this server.',
      );
    }
  });

  // Inspect JSON bodies prior to schema validation
  app.addHook('preValidation', async (req: FastifyRequest) => {
    if (req.body !== undefined && req.body !== null) {
      inspectValueForProhibitedMedia(req.body);
    }
  });
}

