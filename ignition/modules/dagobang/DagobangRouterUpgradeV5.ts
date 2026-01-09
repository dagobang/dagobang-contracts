import { getSelectedNetwork } from "@/utils/network.js";
import { getDeploymentArgs } from "@/utils/readDeployment.js";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DagobangRouterUpgradeV5Module = buildModule("DagobangRouterUpgradeV5Module", (m) => {
  const network = getSelectedNetwork();

  const args = getDeploymentArgs(network).DagobangProxy;
  const proxyAddress = args.proxyAddress;
  const upgradeCallData = args.upgradeCallData;

  const routerProxy = m.contractAt("DagobangProxy", proxyAddress, { id: "DagobangRouterProxy" });
  const routerImplementation = m.contract("DagobangRouter");

  m.call(routerProxy, "upgradeToAndCall", [routerImplementation, upgradeCallData], {
    after: [routerImplementation],
    id: "DagobangRouterProxy_upgradeToAndCall_V5",
  });

  return {
    routerImplementation,
    routerProxy,
  };
});

export default DagobangRouterUpgradeV5Module;

