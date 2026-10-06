import { test } from 'node:test';
import assert from 'node:assert/strict';
import { access } from 'node:fs/promises';
import { swiftEvaluator } from '../src/fibot-engine.js';

test('Swift subprocess adapter requires an absolute executable and redacts launch failures', async () => {
  assert.throws(() => swiftEvaluator('relative-command'));
  await assert.rejects(swiftEvaluator('/nonexistent/fibot-evaluate')({ context: {} }), { code: 'FIBOT_EVALUATION_FAILED' });
});

test('shared Swift executable produces a real monitoring result when explicitly configured', async t => {
  const path = process.env.FIBOT_TEST_EXECUTABLE;
  if (!path) { t.skip('Set FIBOT_TEST_EXECUTABLE after building the shared Swift package.'); return; }
  await access(path);
  const evaluate = swiftEvaluator(path);
  const context = { evaluatedOn: '2026-10-06', horizonEnd: '2027-01-04', accounts: [{ id: 'cash', kind: 'cash',
    available: { amount: '1000', currency: 'CAD' }, protectedReserve: 100, observedOn: '2026-10-06', verification: 'confirmed' }],
    flows: [], commitments: [], coverage: { incomeConfirmed: true, obligationsConfirmed: true, accountsComplete: true,
      spendingIncluded: true, debtPaymentsIncluded: true } };
  const decision = await evaluate({ context });
  assert.equal(decision.outcome, 'affordable'); assert.equal(decision.maximumNow.amount, '900');
  context.coverage.incomeConfirmed = false;
  assert.equal((await evaluate({ context })).outcome, 'needsMoreInformation');
});
