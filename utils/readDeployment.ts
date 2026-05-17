import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

// ESM-safe __dirname resolution
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PROJECT_ROOT = path.resolve(__dirname, "..");
const CONFIG_PATH = path.resolve(PROJECT_ROOT, "ignition/config");
const DEPLOYMENT_PATH = path.resolve(PROJECT_ROOT, "ignition/deployments");

export function getDeploymentArgs(networkName: string) {
  let folderName = networkName;
  if (networkName === "hardhat") {
    folderName = "localhost";
  }

  const filepath = path.resolve(CONFIG_PATH, `${folderName}.json`);
  if (!fs.existsSync(filepath)) {
    throw new Error("missing ignition config file for network " + networkName);
  }
  const data = JSON.parse(fs.readFileSync(filepath, "utf8"));

  return data;
}

export function getDeploymentAddresses(chainId: string, networkName?: string) {
  const folderName = `chain-${chainId}`;
  const networkFolderName = fs.readdirSync(DEPLOYMENT_PATH).filter((f) => f === folderName)[0];
  if (networkFolderName === undefined) {
    throw new Error("missing deployment files for endpoint " + folderName);
  }
  const filepath = path.resolve(DEPLOYMENT_PATH, folderName, `deployed_addresses.json`);
  const data = JSON.parse(fs.readFileSync(filepath, "utf8"));

  const moduleSpec = resolveRouterModuleSpec(networkName, data);
  const dagobangRouterProxy = data[moduleSpec.deployProxyKey];
  const dagobangRouterImplementation = data[moduleSpec.deployImplementationKey];
  const dagobangUpgradableRouter = resolveLatestUpgradedRouter(data, moduleSpec.upgradeImplementationPrefix);

  return {
    MockUSDT: data["MocksModule#MockUSDT"],
    MockBinanceLife: data["MocksModule#MockBinanceLife"],

    DagobangRouterProxy: dagobangRouterProxy,
    DagobangRouterImplementation: dagobangRouterImplementation,
    DagobangUpgradableRouter: dagobangUpgradableRouter,
  };
}

function resolveLatestUpgradedRouter(data: Record<string, string>, upgradeImplementationPrefix: string): string | undefined {
  // Preferred: generic upgrade module (supports releaseTag-based IDs).
  const genericKeys = Object.keys(data).filter((key) =>
    new RegExp(`^${escapeRegExp(upgradeImplementationPrefix)}(?:_.+)?$`).test(key),
  );
  if (genericKeys.length > 0) {
    return data[genericKeys[genericKeys.length - 1]];
  }

  // Backward-compat: legacy versioned modules DagobangRouterUpgradeVxModule.
  const versioned = Object.entries(data)
    .map(([key, value]) => {
      const m = key.match(/^DagobangRouterUpgradeV(\d+)Module#DagobangRouter$/);
      return m ? { version: Number(m[1]), value } : undefined;
    })
    .filter((item): item is { version: number; value: string } => item !== undefined)
    .sort((a, b) => a.version - b.version);

  if (versioned.length > 0) {
    return versioned[versioned.length - 1].value;
  }

  // Last fallback: earliest generic key without suffix.
  return data[upgradeImplementationPrefix];
}

function resolveRouterModuleSpec(networkName: string | undefined, data: Record<string, string>) {
  if (networkName === "hyper" || data["DagobangRouterHyperDeployModule#DagobangRouterHyperProxy"]) {
    return {
      deployProxyKey: "DagobangRouterHyperDeployModule#DagobangRouterHyperProxy",
      deployImplementationKey: "DagobangRouterHyperDeployModule#DagobangRouterHyper",
      upgradeImplementationPrefix: "DagobangRouterHyperUpgradeModule#DagobangRouterHyper",
    };
  }

  if (networkName === "eth" || data["DagobangRouterEthDeployModule#DagobangRouterEthProxy"]) {
    return {
      deployProxyKey: "DagobangRouterEthDeployModule#DagobangRouterEthProxy",
      deployImplementationKey: "DagobangRouterEthDeployModule#DagobangRouterEth",
      upgradeImplementationPrefix: "DagobangRouterEthUpgradeModule#DagobangRouterEth",
    };
  }

  return {
    deployProxyKey: "DagobangRouterDeployModule#DagobangRouterProxy",
    deployImplementationKey: "DagobangRouterDeployModule#DagobangRouter",
    upgradeImplementationPrefix: "DagobangRouterUpgradeModule#DagobangRouter",
  };
}

function escapeRegExp(input: string): string {
  return input.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
