import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

export class ServiceError extends Error {
  constructor(code, status = 400) { super(code); this.code = code; this.status = status; }
}

export function digest(value) { return createHash('sha256').update(value).digest(); }
export function secret() { return randomBytes(32).toString('base64url'); }
export function equalDigest(left, right) {
  return Buffer.isBuffer(left) && Buffer.isBuffer(right)
    && left.length === right.length && timingSafeEqual(left, right);
}
export function requiredString(value, max = 16384) {
  if (typeof value !== 'string' || !value.length || value.length > max) throw new ServiceError('INVALID_REQUEST');
  return value;
}
export function uuid(value) {
  if (typeof value !== 'string' || !/^[a-f\d]{8}(?:-[a-f\d]{4}){3}-[a-f\d]{12}$/i.test(value)) {
    throw new ServiceError('INVALID_REQUEST');
  }
  return value;
}
