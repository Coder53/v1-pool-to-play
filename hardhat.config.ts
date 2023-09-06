import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-ethers";
import * as dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.6",
        settings: {
          evmVersion: "berlin",
          optimizer: {
            enabled: true,
            runs: 200, // Customize the number of runs as desired
          },
        },
      },
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200, // Customize the number of runs as desired
          },
        },
      },
    ],
  },
  networks: {
    bscTestnet: {
      url: "https://long-tiniest-orb.bsc-testnet.discover.quiknode.pro/424b617c99085c11c11e920159102dc20977a0d4/",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [process.env.PRIVATE_KEY!],
    },
    goerli: {
      url: "https://eth-goerli.g.alchemy.com/v2/M159zPGUIGLuBugqPlZrIIzvSBA93hfz",
      chainId: 5,
      accounts: [process.env.PRIVATE_KEY!],
    },
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/n-ApUQvituG3OHEsgPNAerd3eER1PxU-",
      chainId: 11155111,
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
