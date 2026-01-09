import { network } from "hardhat";
import { parseEther, zeroAddress } from "viem";

async function main() {
  const { networkHelpers } = await network.connect();
  const blockTime = await networkHelpers.time.latest();
  const now = Math.round(Date.now() / 1000);
  if (now < blockTime) {
    await networkHelpers.time.increaseTo(BigInt(now));
    console.log(`Block time increased to ${now}`);
  }
  console.log(`Current block time: ${blockTime}`);

}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
