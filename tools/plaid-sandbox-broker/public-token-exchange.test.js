'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createPublicTokenExchanger } = require('./public-token-exchange');

function fixture() {
  const state = { calls: 0, fail: false, failMetadata: false };
  const itemStore = new Map();
  const plaid = {
    async itemPublicTokenExchange() {
      state.calls++;
      if (state.fail) throw new Error('offline');
      return { data: { access_token: 'test-access', item_id: 'test-item' } };
    },
    async itemGet() {
      if (state.failMetadata) throw new Error('metadata unavailable');
      return { data: { item: { institution_id: 'test-bank' } } };
    },
    async institutionsGetById() {
      return { data: { institution: { name: 'Test Bank' } } };
    },
  };
  return { state, itemStore, exchange: createPublicTokenExchanger({
    plaid, countryCodes: ['CA'], itemStore,
  }) };
}

test('concurrent requests and a lost-response retry reuse one exchange and handle', async () => {
  const { state, itemStore, exchange } = fixture();
  const [first, concurrent] = await Promise.all([exchange('test-public'), exchange('test-public')]);
  const retry = await exchange('test-public');
  assert.deepEqual(concurrent, first);
  assert.deepEqual(retry, first);
  assert.equal(state.calls, 1);
  assert.equal(itemStore.size, 1);
  assert.equal(itemStore.get(first.item_id).accessToken, 'test-access');
  assert.equal('access_token' in first, false);
});

test('an unsuccessful exchange can be retried after the upstream connection recovers', async () => {
  const { state, itemStore, exchange } = fixture();
  state.fail = true;
  await assert.rejects(exchange('test-public'), /offline/);
  assert.equal(itemStore.size, 0);
  state.fail = false;
  await exchange('test-public');
  assert.equal(state.calls, 2);
  assert.equal(itemStore.size, 1);
});

test('metadata failure preserves a completed exchange for replay', async () => {
  const { state, itemStore, exchange } = fixture();
  state.failMetadata = true;
  const first = await exchange('test-public');
  assert.equal(first.institution_name, null);
  assert.deepEqual(await exchange('test-public'), first);
  assert.equal(state.calls, 1);
  assert.equal(itemStore.size, 1);
});
