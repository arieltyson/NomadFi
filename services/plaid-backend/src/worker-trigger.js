// Starts the sync worker as soon as work is queued, instead of waiting
// for its schedule. The schedule remains the fallback: a failed or
// skipped trigger only delays work until the next scheduled run.

const JOB_NAME = /^projects\/[a-z][a-z0-9-]{4,28}[a-z0-9]\/locations\/[a-z0-9-]+\/jobs\/[a-z][a-z0-9-]{0,62}$/;
const METADATA_TOKEN = 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token';

export class WorkerTrigger {
  /**
   * @param {object} options
   * @param {string | undefined} options.jobName Full Cloud Run job name; without it the trigger does nothing.
   * @param {number} [options.coalesceMs] Requests within this window share one execution. A run that has
   *   just started is still booting when they arrive and claims their work too.
   * @param {number} [options.timeoutMs] Upper bound on how long a caller waits for the start request.
   */
  constructor({ jobName, fetch = globalThis.fetch, clock = () => Date.now(), coalesceMs = 5000, timeoutMs = 3000, logger = () => {} } = {}) {
    if (jobName !== undefined && !JOB_NAME.test(jobName)) throw new Error('Invalid worker job name');
    this.jobName = jobName; this.fetch = fetch; this.clock = clock;
    this.coalesceMs = coalesceMs; this.timeoutMs = timeoutMs; this.logger = logger;
    this.lastStartedAt = -Infinity;
  }

  /**
   * Starts one worker execution unless one started moments ago. Awaited
   * by callers because Cloud Run withholds CPU once a response is sent;
   * never throws, so queued work is acknowledged either way.
   * @returns {Promise<'started' | 'coalesced' | 'disabled' | 'failed'>}
   */
  async request() {
    if (!this.jobName) return 'disabled';
    const now = this.clock();
    if (now - this.lastStartedAt < this.coalesceMs) return 'coalesced';
    this.lastStartedAt = now;
    const signal = AbortSignal.timeout(this.timeoutMs);
    try {
      const token = await this.fetch(METADATA_TOKEN, { headers: { 'Metadata-Flavor': 'Google' }, signal });
      if (!token.ok) throw new Error(`token ${token.status}`);
      const { access_token: accessToken } = await token.json();
      const run = await this.fetch(`https://run.googleapis.com/v2/${this.jobName}:run`, {
        method: 'POST', signal,
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: '{}',
      });
      if (!run.ok) throw new Error(`run ${run.status}`);
      this.logger({ event: 'worker_triggered' });
      return 'started';
    } catch (error) {
      // Let the next request retry rather than coalescing into a start that failed.
      this.lastStartedAt = -Infinity;
      this.logger({ event: 'worker_trigger_failed', reason: error.name === 'TimeoutError' ? 'timeout' : String(error.message).slice(0, 40) });
      return 'failed';
    }
  }
}
