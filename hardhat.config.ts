import "dotenv/config";
import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable, defineConfig } from "hardhat/config";
import hardhatVerify from "@nomicfoundation/hardhat-verify";
import hardhatNetworkHelpers from "@nomicfoundation/hardhat-network-helpers";
import checkGasTask from "./tasks/checkGas/index.js";
import setFeeTask from "./tasks/setFee/index.js";
import verifyContractTask from "./tasks/verify/index.js";

export default defineConfig({
  plugins: [hardhatToolboxViemPlugin, hardhatNetworkHelpers, hardhatVerify],
  tasks: [checkGasTask, setFeeTask, verifyContractTask],
  chainDescriptors: {
    999: {
      name: "hyper",
      chainType: "l1",
      blockExplorers: {
        etherscan: {
          name: "HyperScan",
          url: "https://www.hyperscan.com",
          apiUrl: "https://api.etherscan.io/v2/api",
        },
      },
    },
  },
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1,
          },
          viaIR: true,
        },
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1,
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
      url: "https://bsc-dataseed-public.bnbchain.org",
      accounts: [configVariable("PROD_DEPLOYER"), configVariable("PROD_ADMIN")],
      gasPrice: 300000000, //0.3Gwei
      ignition: {
        maxFeePerGas: 1000000000n, // 1.0 Gwei cap for type-2 txs
        maxPriorityFeePerGas: 500000000n, // 0.5 Gwei tip to match current deploy setting
      },
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
    eth: {
      type: "http",
      chainType: "l1",
      url: configVariable("ETH_RPC_URL"),
      accounts: [configVariable("ETH_DEPLOYER"), configVariable("ETH_ADMIN")],
      chainId: 1,
      timeout: 600000,
    },
    hyper: {
      type: "http",
      chainType: "l1",
      url: "https://rpc.hypurrscan.io",
      accounts: [configVariable("PROD_DEPLOYER"), configVariable("PROD_ADMIN")],
      gasPrice: process.env.HYPER_GAS_PRICE ? BigInt(process.env.HYPER_GAS_PRICE) : 10000000000n,
      ignition: {
        maxFeePerGas: process.env.HYPER_MAX_FEE_PER_GAS ? BigInt(process.env.HYPER_MAX_FEE_PER_GAS) : 12000000000n,
        maxPriorityFeePerGas: process.env.HYPER_MAX_PRIORITY_FEE_PER_GAS
          ? BigInt(process.env.HYPER_MAX_PRIORITY_FEE_PER_GAS)
          : 1000000000n,
      },
      chainId: 999,
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
      apiKey: process.env.ETHERSCAN_API_KEY || process.env.BSCSCAN_API_KEY || process.env.BSC_TEST_SCAN_API_KEY || "",
    },
  },
});
