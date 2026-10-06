import { createHash, randomUUID } from 'node:crypto';
import { transaction } from './database.js';
import { ServiceError, uuid } from './security.js';

const categories = ['cash_shortfall', 'stale_context'];
const object = value => value && typeof value === 'object' && !Array.isArray(value);
export function monitorSettings(value) {
  if (!object(value) || !Array.isArray(value.categories) || value.categories.some(item => !categories.includes(item))
      || !Number.isInteger(value.quietStart) || !Number.isInteger(value.quietEnd)
      || value.quietStart < 0 || value.quietStart > 23 || value.quietEnd < 0 || value.quietEnd > 23
      || typeof value.timeZone !== 'string' || value.timeZone.length > 100) throw new ServiceError('INVALID_MONITOR_SETTINGS');
  try { new Intl.DateTimeFormat('en', { timeZone: value.timeZone }).format(); } catch { throw new ServiceError('INVALID_MONITOR_SETTINGS'); }
  const snooze = value.snoozedUntil == null ? null : new Date(value.snoozedUntil);
  if (snooze && (!Number.isFinite(snooze.getTime()) || snooze.getTime() > Date.now() + 90 * 86400000)) throw new ServiceError('INVALID_MONITOR_SETTINGS');
  return { categories: [...new Set(value.categories)], quietStart: value.quietStart, quietEnd: value.quietEnd,
    timeZone: value.timeZone, snoozedUntil: snooze?.toISOString() ?? null };
}

export class FiBotService {
  constructor(pool) { this.pool = pool; }
  async configure(userID, input) {
    if (typeof input.consent !== 'boolean') throw new ServiceError('MONITOR_CONSENT_REQUIRED');
    return transaction(this.pool, async client => {
      const user = (await client.query("SELECT delivery_revision FROM nomadfi.users WHERE id = $1 AND state = 'active' FOR UPDATE", [userID])).rows[0];
      if (!user) throw new ServiceError('NOT_FOUND', 404);
      if (!input.consent) {
        await client.query('DELETE FROM nomadfi.fibot_profiles WHERE user_id = $1', [userID]);
        return { enabled: false };
      }
      const settings = monitorSettings(input.settings);
      if (!object(input.context) || !object(input.policy) || input.policy.version !== 'cash-flow-v1'
          || !Array.isArray(input.context.accounts) || input.context.accounts.length > 100
          || !Array.isArray(input.context.flows) || input.context.flows.length > 1500
          || !Array.isArray(input.context.commitments) || input.context.commitments.length > 1000
          || !object(input.context.coverage) || Buffer.byteLength(JSON.stringify(input.context)) > 131072) {
        throw new ServiceError('INVALID_MONITOR_CONTEXT');
      }
      const previous = (await client.query('SELECT revision FROM nomadfi.fibot_profiles WHERE user_id = $1 FOR UPDATE', [userID])).rows[0];
      if (String(input.expectedRevision ?? '0') !== (previous?.revision ?? '0')) throw new ServiceError('MONITOR_PLAN_CHANGED', 409);
      const result = (await client.query(`INSERT INTO nomadfi.fibot_profiles (user_id, context, policy, settings, bank_revision, confirmed_bank_revision)
        VALUES ($1, $2, $3, $4, $5, $5) ON CONFLICT (user_id) DO UPDATE SET context = EXCLUDED.context,
        policy = EXCLUDED.policy, settings = EXCLUDED.settings, revision = nomadfi.fibot_profiles.revision + 1,
        bank_revision = EXCLUDED.bank_revision, confirmed_bank_revision = EXCLUDED.confirmed_bank_revision,
        updated_at = clock_timestamp() RETURNING revision`,
      [userID, input.context, input.policy, settings, user.delivery_revision])).rows[0];
      await client.query(`INSERT INTO nomadfi.fibot_jobs (user_id) VALUES ($1) ON CONFLICT (user_id) DO UPDATE
        SET requested_revision = nomadfi.fibot_jobs.requested_revision + 1, available_at = clock_timestamp(),
          attempts = 0, dead_letter = false`, [userID]);
      await client.query('UPDATE nomadfi.fibot_alerts SET superseded = true WHERE user_id = $1', [userID]);
      return { enabled: true, revision: result.revision };
    });
  }
  async status(userID) {
    const profile = (await this.pool.query('SELECT revision, settings, updated_at FROM nomadfi.fibot_profiles WHERE user_id = $1', [userID])).rows[0];
    const alerts = (await this.pool.query(`SELECT id, category, decision, created_at, notification_at FROM nomadfi.fibot_alerts
      WHERE user_id = $1 AND NOT superseded AND dismissed_at IS NULL ORDER BY created_at DESC LIMIT 20`, [userID])).rows;
    return { enabled: Boolean(profile), revision: profile?.revision ?? '0', settings: profile?.settings ?? null, alerts };
  }
  async dismiss(userID, id) {
    await this.pool.query('UPDATE nomadfi.fibot_alerts SET dismissed_at = clock_timestamp() WHERE id = $1 AND user_id = $2', [uuid(id), userID]);
    return { status: 'dismissed' };
  }
}

export function notificationAllowed(settings, now) {
  if (settings.snoozedUntil && new Date(settings.snoozedUntil) > now) return false;
  const hour = Number(new Intl.DateTimeFormat('en', { timeZone: settings.timeZone, hour: 'numeric', hourCycle: 'h23' }).format(now));
  return settings.quietStart === settings.quietEnd || (settings.quietStart < settings.quietEnd
    ? hour < settings.quietStart || hour >= settings.quietEnd : hour < settings.quietStart && hour >= settings.quietEnd);
}

export class FiBotMonitor {
  constructor({ pool, evaluate, now = () => new Date() }) { this.pool = pool; this.evaluate = evaluate; this.now = now; }
  async runOne() {
    const claim = await transaction(this.pool, async client => (await client.query(`WITH candidate AS (
      SELECT user_id FROM nomadfi.fibot_jobs WHERE requested_revision > completed_revision AND NOT dead_letter
        AND available_at <= clock_timestamp() AND (lease_expires_at IS NULL OR lease_expires_at < clock_timestamp())
      ORDER BY available_at FOR UPDATE SKIP LOCKED LIMIT 1)
      UPDATE nomadfi.fibot_jobs j SET lease_epoch = lease_epoch + 1, lease_expires_at = clock_timestamp() + interval '2 minutes'
      FROM candidate c WHERE j.user_id = c.user_id RETURNING j.*`)).rows[0]);
    if (!claim) return { status: 'idle' };
    try {
      const profile = await transaction(this.pool, async client => {
        const row = (await client.query('SELECT * FROM nomadfi.fibot_profiles WHERE user_id = $1 FOR SHARE', [claim.user_id])).rows[0];
        if (!row) return null;
        row.connections = (await client.query('SELECT * FROM nomadfi.fibot_connections WHERE user_id = $1', [claim.user_id])).rows;
        return row;
      });
      if (!profile) return { status: 'obsolete' };
      const parts = new Intl.DateTimeFormat('en', { timeZone: profile.settings.timeZone,
        year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(this.now());
      const today = ['year', 'month', 'day'].map(type => parts.find(part => part.type === type).value).join('-');
      const context = structuredClone(profile.context);
      const originalDate = context.evaluatedOn;
      context.evaluatedOn = today;
      context.flows = context.flows.filter(flow => typeof flow.date === 'string' && flow.date >= today);
      if (profile.connections.some(connection => connection.state !== 'connected')
          || profile.updated_at.getTime() < this.now().getTime() - 30 * 86400000) context.coverage.accountsComplete = false;
      // Uploaded manual cash is not replaced by cached provider balances with an unknown observation time.
      if (today !== originalDate || profile.bank_revision !== profile.confirmed_bank_revision) context.coverage.accountsComplete = false;
      const decision = await this.evaluate({ context, policy: profile.policy });
      if (!decision || !['affordable', 'affordableWithTradeoffs', 'wait', 'needsMoreInformation'].includes(decision.outcome)
          || !Array.isArray(decision.reasons) || decision.policyVersion !== 'cash-flow-v1'
          || Buffer.byteLength(JSON.stringify(decision)) > 1048576) throw new ServiceError('INVALID_ENGINE_RESULT');
      const category = decision.outcome === 'needsMoreInformation' ? 'stale_context'
        : decision.outcome === 'wait' || decision.outcome === 'affordableWithTradeoffs' ? 'cash_shortfall' : null;
      return await transaction(this.pool, async client => {
        const current = (await client.query('SELECT revision, bank_revision FROM nomadfi.fibot_profiles WHERE user_id = $1 FOR SHARE', [claim.user_id])).rows[0];
        const job = (await client.query(`SELECT * FROM nomadfi.fibot_jobs WHERE user_id = $1 AND lease_epoch = $2
          AND lease_expires_at > clock_timestamp() FOR UPDATE`, [claim.user_id, claim.lease_epoch])).rows[0];
        if (!job || current?.revision !== profile.revision || current?.bank_revision !== profile.bank_revision) return { status: 'obsolete' };
        await client.query('UPDATE nomadfi.fibot_alerts SET superseded = true WHERE user_id = $1', [claim.user_id]);
        if (category && profile.settings.categories.includes(category)) {
          const fingerprint = createHash('sha256').update(`${profile.revision}:${category}:${decision.reasons.slice().sort().join(',')}`).digest('hex');
          const recent = (await client.query(`SELECT count(*) AS weekly, count(*) FILTER (WHERE notification_at > clock_timestamp() - interval '1 day') AS daily
            FROM nomadfi.fibot_alerts WHERE user_id = $1 AND notification_at > clock_timestamp() - interval '7 days'`, [claim.user_id])).rows[0];
          const notify = notificationAllowed(profile.settings, this.now()) && Number(recent.daily) === 0 && Number(recent.weekly) < 3;
          await client.query(`INSERT INTO nomadfi.fibot_alerts
            (id, user_id, profile_revision, bank_revision, category, fingerprint, decision, notification_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, CASE WHEN $8 THEN clock_timestamp() ELSE NULL END)
            ON CONFLICT (user_id, fingerprint) DO UPDATE SET decision = EXCLUDED.decision,
              bank_revision = EXCLUDED.bank_revision, superseded = false,
              notification_at = CASE WHEN nomadfi.fibot_alerts.dismissed_at IS NULL
                THEN coalesce(nomadfi.fibot_alerts.notification_at, EXCLUDED.notification_at)
                ELSE nomadfi.fibot_alerts.notification_at END`,
          [randomUUID(), claim.user_id, profile.revision, profile.bank_revision, category, fingerprint, decision, notify]);
        }
        await client.query(`UPDATE nomadfi.fibot_jobs SET completed_revision = $3, lease_expires_at = NULL,
          attempts = 0 WHERE user_id = $1 AND lease_epoch = $2`, [claim.user_id, claim.lease_epoch, claim.requested_revision]);
        return { status: 'evaluated' };
      });
    } catch {
      await this.pool.query(`UPDATE nomadfi.fibot_jobs SET attempts = attempts + 1, dead_letter = attempts + 1 >= 8,
        lease_expires_at = NULL, available_at = clock_timestamp() + interval '5 minutes' WHERE user_id = $1 AND lease_epoch = $2`,
      [claim.user_id, claim.lease_epoch]);
      return { status: 'retry' };
    }
  }
}
