import { task } from "hardhat/config";

export default task("verifyContract", "verify the smartcontracts")
  .setAction(async () => import("./task-action.js"))
  .build();
