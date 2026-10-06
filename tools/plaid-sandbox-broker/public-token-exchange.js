'use strict';

const crypto = require('node:crypto');

function createPublicTokenExchanger({ plaid, countryCodes, itemStore }) {
  const exchanges = new Map();

  return function exchange(publicToken) {
    const key = crypto.createHash('sha256').update(publicToken).digest('hex');
    if (exchanges.has(key)) return exchanges.get(key);

    // Share in-flight work and replay its result if the phone loses the response.
    const pending = finishExchange(publicToken).catch(error => {
      exchanges.delete(key);
      throw error;
    });
    exchanges.set(key, pending);
    return pending;
  };

  async function finishExchange(publicToken) {
    const exchanged = await plaid.itemPublicTokenExchange({ public_token: publicToken });
    const accessToken = exchanged.data.access_token;
    const plaidItemID = exchanged.data.item_id;
    const itemHandle = 'itm_' + crypto.randomBytes(12).toString('hex');
    itemStore.set(itemHandle, { accessToken, plaidItemID });

    let institutionID = null;
    let institutionName = null;
    try {
      const item = await plaid.itemGet({ access_token: accessToken });
      institutionID = item.data.item.institution_id || null;
      if (institutionID) {
        const institution = await plaid.institutionsGetById({
          institution_id: institutionID, country_codes: countryCodes,
        });
        institutionName = institution.data.institution.name;
      }
    } catch (_) {
      // Institution metadata must not discard a successful token exchange.
    }
    return {
      item_id: itemHandle,
      institution_id: institutionID,
      institution_name: institutionName,
      plaid_item_id: plaidItemID,
    };
  }
}

module.exports = { createPublicTokenExchanger };
