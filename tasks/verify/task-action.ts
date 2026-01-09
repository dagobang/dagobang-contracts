import { getSelectedNetwork, isLocal } from "@/utils/network.js";
import { getDeploymentAddresses } from "@/utils/readDeployment.js";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";
import { verifyContract } from "@nomicfoundation/hardhat-verify/verify";

export const tryVerify = async (fn: Promise<any>) => {
  try {
    return await fn;
  } catch (ex) {
    console.error(ex);
  }
};

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PROJECT_ROOT = path.resolve(__dirname, "..", "..");
const DEPLOYMENT_PATH = path.resolve(PROJECT_ROOT, "ignition", "deployments");

function getProxyConstructorArgs(chainId: bigint): string[] | undefined {
  const chainFolder = `chain-${chainId.toString()}`;
  const journalPath = path.resolve(DEPLOYMENT_PATH, chainFolder, "journal.jsonl");
  if (!fs.existsSync(journalPath)) {
    console.warn(`journal file not found for ${chainFolder}, skip proxy verification`);
    return undefined;
  }

  const lines = fs.readFileSync(journalPath, "utf8").split("\n");
  for (const line of lines) {
    if (!line.trim()) continue;
    try {
      const entry = JSON.parse(line);
      if (
        entry.artifactId === "DagobangRouterDeployModule#DagobangRouterProxy" &&
        Array.isArray(entry.constructorArgs)
      ) {
        return entry.constructorArgs as string[];
      }
    } catch {
    }
  }

  console.warn("constructorArgs for DagobangRouterProxy not found in journal, skip proxy verification");
  return undefined;
}

export default async function action(_args: any, hre: any) {
  const { viem } = await hre.network.connect();
  const publicClient = await viem.getPublicClient();
  const chainId = await publicClient.getChainId();

  const network = getSelectedNetwork();
  console.log(`network: >> ${network}, chainId: ${chainId}`);

  if (isLocal()) {
    console.log("local network detected, skip etherscan verification");
    return;
  }

  const addresses = getDeploymentAddresses(`${chainId}`);

  await tryVerify(
    verifyContract(
      {
        address: addresses.DagobangRouterImplementation,
        constructorArgs: [],
        provider: "etherscan",
      },
      hre,
    ),
  );

  const proxyConstructorArgs = getProxyConstructorArgs(chainId);
  if (!proxyConstructorArgs) {
    return;
  }

  await tryVerify(
    verifyContract(
      {
        address: addresses.DagobangRouterProxy,
        constructorArgs: proxyConstructorArgs,
        provider: "etherscan",
      },
      hre,
    ),
  );

  if (addresses.DagobangUpgradableRouter) {
    await tryVerify(
      verifyContract(
        {
          address: addresses.DagobangUpgradableRouter,
          constructorArgs: [],
          provider: "etherscan",
        },
        hre,
      ),
    );
  }
}
