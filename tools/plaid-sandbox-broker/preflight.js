'use strict';

require('dotenv').config();
const { Products, CountryCode } = require('plaid');
const { parseConfig, parsePlaidEnumList } = require('./config');

try {
  const config = parseConfig(process.env);
  const countries = parsePlaidEnumList(config.countryCodesRaw, CountryCode);
  const products = parsePlaidEnumList(config.productsRaw, Products);
  console.log(JSON.stringify({
    configuration_valid: true,
    environment: config.plaidEnv,
    live_data_opted_in: config.isLiveDataEvaluation,
    countries,
    products,
    reachability: config.isLoopbackMode ? 'loopback' : 'LAN with shared secret',
    redirect_configured: config.redirectURI !== null,
    canadian_evaluation_scope: countries.length === 1 && countries[0] === 'CA'
      && products.length === 1 && products[0] === 'transactions'
      && config.redirectURI === null,
    production_access: 'not checked; confirm plan, Canada, and Transactions in Plaid Dashboard',
    token_storage: 'memory only; keep broker running through the evaluation',
  }, null, 2));
} catch (error) {
  console.error(`[plaid-preflight] ${error.code || 'CONFIG_ERROR'}: ${error.message}`);
  process.exitCode = 1;
}
