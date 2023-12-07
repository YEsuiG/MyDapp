// migrations/2_deploy_contracts.js
const SupplyChain = artifacts.require("Supplychain.sol");

module.exports = function (deployer) {
  deployer.deploy(SupplyChain);
};