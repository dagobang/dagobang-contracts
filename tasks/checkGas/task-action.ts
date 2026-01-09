import { getSelectedNetwork } from "@/utils/network.js";

export default async function action(_args: any, hre: any) {
  const { viem } = await hre.network.connect();
  const publicClient = await viem.getPublicClient();

  const network = getSelectedNetwork();
  const feeData = await publicClient.getFeeData();

  console.log(`network: >> ${network}`);
  console.log("gasPrice:", hre.ethers.formatUnits(feeData.gasPrice || 0, "gwei") + " gwei");
  console.log(
    "Suggested maxPriorityFeePerGas:",
    hre.ethers.formatUnits(feeData.maxPriorityFeePerGas || 0, "gwei"),
    "gwei",
  );
  console.log("Suggested maxFeePerGas:", hre.ethers.formatUnits(feeData.maxFeePerGas || 0, "gwei"), "gwei");
}
