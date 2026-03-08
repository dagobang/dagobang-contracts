import { getSelectedNetwork } from "@/utils/network.js";
import { getDeploymentAddresses } from "@/utils/readDeployment.js";

const parseBoolean = (value: string | undefined): boolean | undefined => {
  if (value === undefined) return undefined;
  if (value === "true" || value === "1") return true;
  if (value === "false" || value === "0") return false;
  return undefined;
};

const getArgValue = (name: string): string | undefined => {
  const argv = process.argv || [];
  const idx = argv.indexOf(`--${name}`);
  if (idx !== -1 && idx + 1 < argv.length) {
    return argv[idx + 1];
  }
  const inline = argv.find((a) => a.startsWith(`--${name}=`));
  if (inline) {
    return inline.split("=")[1];
  }
  return undefined;
};

export default async function action(args: any, hre: any) {
  const { viem } = await hre.network.connect();
  const publicClient = await viem.getPublicClient();
  const chainId = await publicClient.getChainId();

  const network = getSelectedNetwork();
  console.log(`network: >> ${network}, chainId: ${chainId}`);

  const addresses = getDeploymentAddresses(`${chainId}`);
  const routerAddress = addresses.DagobangRouterProxy;

  if (!routerAddress) {
    throw new Error("missing DagobangRouter address");
  }

  const proxyAbi = [
    {
      type: "function",
      name: "admin",
      stateMutability: "view",
      inputs: [],
      outputs: [{ type: "address" }],
    },
  ] as const;
  const ownerAbi = [
    {
      type: "function",
      name: "owner",
      stateMutability: "view",
      inputs: [],
      outputs: [{ type: "address" }],
    },
  ] as const;

  const router = await viem.getContractAt("DagobangRouter", routerAddress);
  const walletClients = (await viem.getWalletClients()) as Array<{ account: { address: string } }>;
  let admin: string | undefined;
  try {
    admin = (await publicClient.readContract({
      address: routerAddress,
      abi: proxyAbi,
      functionName: "admin",
    })) as string;
  } catch {
  }
  const adminLower = admin?.toLowerCase();
  const readAccount = walletClients.find((client) => client.account.address.toLowerCase() !== adminLower);
  const owner = (
    await publicClient.readContract({
      address: routerAddress,
      abi: ownerAbi,
      functionName: "owner",
      account: readAccount?.account.address as any,
    })
  ).toLowerCase();
  if (adminLower && owner === adminLower) {
    throw new Error(`proxy admin equals owner. change admin first: admin=${adminLower}`);
  }
  const caller = walletClients.find((client) => client.account.address.toLowerCase() === owner);
  if (!caller) {
    const available = walletClients.map((client) => client.account.address).join(", ");
    throw new Error(`owner not found in configured accounts. owner=${owner}, available=${available}`);
  }

  const feeCollector = args?.feeCollector ?? getArgValue("feeCollector");
  const feeBps = args?.feeBps ?? getArgValue("feeBps");
  const feeThreshold = args?.feeThreshold ?? getArgValue("feeThreshold");
  const feeExemptAccount = args?.feeExemptAccount ?? getArgValue("feeExemptAccount");
  const feeExempt = args?.feeExempt ?? getArgValue("feeExempt");
  const hasAny =
    feeCollector !== undefined ||
    feeBps !== undefined ||
    feeThreshold !== undefined ||
    feeExemptAccount !== undefined;

  if (!hasAny) {
    console.log("no params provided");
    return;
  }

  if (feeCollector !== undefined) {
    const hash = await router.write.setFeeCollector([feeCollector], { account: caller.account });
    await publicClient.waitForTransactionReceipt({ hash });
    console.log(`setFeeCollector tx: ${hash}`);
  }

  if (feeBps !== undefined) {
    const bps = BigInt(feeBps);
    const hash = await router.write.setFeeBps([bps], { account: caller.account });
    await publicClient.waitForTransactionReceipt({ hash });
    console.log(`setFeeBps tx: ${hash}`);
  }

  if (feeExemptAccount !== undefined) {
    const isExempt = parseBoolean(feeExempt) ?? true;
    const hash = await router.write.setFeeExempt([feeExemptAccount, isExempt], { account: caller.account });
    await publicClient.waitForTransactionReceipt({ hash });
    console.log(`setFeeExempt tx: ${hash}`);
  }

  if (feeThreshold !== undefined) {
    const threshold = BigInt(feeThreshold);
    const hash = await router.write.setFeeThreshold([threshold], { account: caller.account });
    await publicClient.waitForTransactionReceipt({ hash });
    console.log(`setFeeThreshold tx: ${hash}`);
  }
}
