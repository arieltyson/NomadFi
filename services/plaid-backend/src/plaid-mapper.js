import { ServiceError, requiredString } from './security.js';

const invalid = () => new ServiceError('PROVIDER_INVALID_DATA', 502);
function optional(value, limit = 512) { return value == null ? null : requiredString(value, limit); }
function money(value) {
  if (value == null) return null;
  if (typeof value !== 'number' || !Number.isFinite(value) || Math.abs(value) >= 1e14
      || !/^-?\d+(\.\d{1,8})?$/.test(String(value))) throw invalid();
  return String(value);
}
function date(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)
      || new Date(value).toISOString().slice(0, 10) !== value) throw invalid();
  return value;
}
function timestamp(value) {
  if (value == null) return null;
  const parsed = new Date(value);
  if (!Number.isFinite(parsed.getTime())) throw invalid();
  return parsed.toISOString();
}
function currency(value) {
  if (value == null) return null;
  if (typeof value !== 'string' || !/^[A-Z]{3}$/.test(value)) throw invalid();
  return value;
}
export function mapAccounts(accounts, fetchedAt) {
  if (!Array.isArray(accounts) || accounts.length > 200) throw invalid();
  const ids = new Set();
  return accounts.map(account => {
    const id = requiredString(account.account_id, 512);
    if (ids.has(id)) throw invalid(); ids.add(id);
    return { kind: 'account', externalID: id, payload: {
      name: requiredString(account.name, 512), type: requiredString(account.type, 64),
      subtype: optional(account.subtype, 64), currency: currency(account.balances?.iso_currency_code),
      current: money(account.balances?.current), available: money(account.balances?.available),
      limit: money(account.balances?.limit), fetched_at: fetchedAt,
      balance_observed_at: timestamp(account.balances?.last_updated_datetime),
    } };
  });
}
export function mapTransactions(page) {
  if (!Array.isArray(page.added) || !Array.isArray(page.modified) || !Array.isArray(page.removed)
      || page.added.length + page.modified.length + page.removed.length > 500
      || typeof page.has_more !== 'boolean' || typeof page.next_cursor !== 'string'
      || page.next_cursor.length > 8192) throw invalid();
  return [...page.added, ...page.modified].map(item => {
    if (typeof item.pending !== 'boolean' || item.amount == null) throw invalid();
    return { kind: 'transaction', externalID: requiredString(item.transaction_id, 512), payload: {
      account_id: requiredString(item.account_id, 512), amount: money(item.amount),
      currency: currency(item.iso_currency_code), date: date(item.date),
      authorized_date: item.authorized_date == null ? null : date(item.authorized_date),
      name: requiredString(item.name, 1024), merchant_name: optional(item.merchant_name, 1024),
      pending: item.pending, pending_transaction_id: optional(item.pending_transaction_id),
      category: optional(item.personal_finance_category?.primary, 128),
      category_detail: optional(item.personal_finance_category?.detailed, 128),
    } };
  }).concat(page.removed.map(item => ({ kind: 'removed_transaction',
    externalID: requiredString(item.transaction_id, 512), payload: {} })));
}
