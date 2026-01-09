import "dotenv/config";
import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable, defineConfig } from "hardhat/config";
import hardhatVerify from "@nomicfoundation/hardhat-verify";
import hardhatNetworkHelpers from "@nomicfoundation/hardhat-network-helpers";
import checkGasTask from "./tasks/checkGas/index.js";
import verifyContractTask from "./tasks/verify/index.js";

export default defineConfig({
  plugins: [hardhatToolboxViemPlugin, hardhatNetworkHelpers, hardhatVerify],
  tasks: [checkGasTask, verifyContractTask],
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true,
        },
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true,
        },
      },
    },
  },
  networks: {
    localhost: {
      // mirror default hardhat network behavior for consistency with 31337
      type: "http",
      url: "http://localhost:8545",
      accounts: {
        mnemonic: "test test test test test test test test test test test junk",
      },
      chainId: 1337,
    },
    // bsc network
    bsc: {
      type: "http",
      url: "https://bsc-dataseed.bnbchain.org",
      accounts: [configVariable("PROD_DEPLOYER"), configVariable("PROD_CALLER")],
      // gasPrice: 5000000000, //5Gwei
      chainId: 56,
      timeout: 600000,
    },
    bscTestnet: {
      type: "http",
      url: "https://data-seed-prebsc-1-s1.bnbchain.org:8545",
      accounts: [configVariable("TEST_DEPLOYER"), configVariable("TEST_CALLER")],
      chainId: 97,
      // gasPrice: 11000000000, //11Gwei
      gas: 8000000,
      timeout: 600000,
    },

    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      url: configVariable("SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
  },
  verify: {
    etherscan: {
      // Your API key for Etherscan
      // Obtain one at https://etherscan.io/
      apiKey: configVariable("BSC_TEST_SCAN_API_KEY"),
    },
  },
});
