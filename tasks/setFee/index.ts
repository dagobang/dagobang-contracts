import { task } from "hardhat/config";
import { ArgumentType } from "hardhat/types/arguments";

export default task("setFee", "set fee params for DagobangRouter")
  .addOption({
    name: "feeCollector",
    description: "fee collector address",
    type: ArgumentType.STRING_WITHOUT_DEFAULT,
    defaultValue: undefined,
  })
  .addOption({
    name: "feeBps",
    description: "fee bps",
    type: ArgumentType.STRING_WITHOUT_DEFAULT,
    defaultValue: undefined,
  })
  .addOption({
    name: "feeThreshold",
    description: "fee threshold",
    type: ArgumentType.STRING_WITHOUT_DEFAULT,
    defaultValue: undefined,
  })
  .addOption({
    name: "feeExemptAccount",
    description: "fee exempt account",
    type: ArgumentType.STRING_WITHOUT_DEFAULT,
    defaultValue: undefined,
  })
  .addOption({
    name: "feeExempt",
    description: "fee exempt true/false",
    type: ArgumentType.STRING_WITHOUT_DEFAULT,
    defaultValue: undefined,
  })
  .setAction(async () => import("./task-action.js"))
  .build();
