import { task } from "hardhat/config";

export default task("checkGas", "check gas price")
  .setAction(async () => import("./task-action.js"))
  .build();
