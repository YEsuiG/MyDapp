const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config();

const GasReporter = require('eth-gas-reporter');
module.exports = {
  networks: {
    sepolia: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`),
      network_id: 11155111, // Sepolia network ID
      gas: 6000000, // Gas limit used for deploys
    },
  },

 
  mocha: {
    timeout: 100000,
    reporter: 'eth-gas-reporter',
    reporterOptions: {
      currency: 'USD',
      gasPrice: 21,
    }
  },

 
  compilers: {
    solc: {
      version: "0.8.22",      
    }
  },


};
