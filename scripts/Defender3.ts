const { ethers } = require("ethers");
const { DefenderRelaySigner, DefenderRelayProvider } = require('defender-relay-client/lib/ethers');

// Entrypoint for the Autotask
exports.handler = async function(params) {
  // Load value provided in the webhook payload (not available in schedule or sentinel invocations)
  const { value } = params.request.body;

  // Compare it with a local secret
  if (value !== event.secrets.expectedValue) return;

  // Initialize defender relayer provider and signer
  const provider = new DefenderRelayProvider(event);
  const signer = new DefenderRelaySigner(event, provider, { speed: 'fast' });

  // Create contract instance from the signer and use it to send a tx
  const contract = new ethers.Contract(ADDRESS, ABI, signer);
  if (await contract.canExecute()) {
    const tx = await contract.execute();
    console.log(`Called execute in ${tx.hash}`);
    return { tx: tx.hash };
  }
}

// To run locally (this code will not be executed in Autotasks)
if (require.main === module) {
  const { API_KEY: apiKey, API_SECRET: apiSecret } = process.env;
  exports.handler({ apiKey, apiSecret })
    .then(() => process.exit(0))
    .catch(error => { console.error(error); process.exit(1); });
}