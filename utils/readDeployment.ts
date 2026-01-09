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

export function getDeploymentAddresses(chainId: string) {
  const folderName = `chain-${chainId}`;
  const networkFolderName = fs.readdirSync(DEPLOYMENT_PATH).filter((f) => f === folderName)[0];
  if (networkFolderName === undefined) {
    throw new Error("missing deployment files for endpoint " + folderName);
  }
  const filepath = path.resolve(DEPLOYMENT_PATH, folderName, `deployed_addresses.json`);
  const data = JSON.parse(fs.readFileSync(filepath, "utf8"));

  const dagobangRouterProxy = data["DagobangRouterDeployModule#DagobangRouterProxy"];
  const dagobangRouterImplementation = data["DagobangRouterDeployModule#DagobangRouter"];
  const dagobangUpgradableRouter = data["DagobangRouterUpgradeV5Module#DagobangRouter"];

  return {
    MockUSDT: data["MocksModule#MockUSDT"],
    MockBinanceLife: data["MocksModule#MockBinanceLife"],

    DagobangRouterProxy: dagobangRouterProxy,
    DagobangRouterImplementation: dagobangRouterImplementation,
    DagobangUpgradableRouter: dagobangUpgradableRouter,
  };
}
