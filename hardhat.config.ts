import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');
const { alchemyApiKey, mnemonic } = require('./secrets.json');

const config: HardhatUserConfig = {
  solidity: "0.8.18",
  etherscan: {
    apiKey: "ABCDE12345ABCDE12345ABCDE123456789",
  },
  networks: {
    ftm: {
      url: `https://rpc.ftm.tools/`,
      accounts: [
        ""
      ]
    }
  }
};

export default config;
