import { getSelectedNetwork } from "@/utils/network.js";
import { getDeploymentArgs } from "@/utils/readDeployment.js";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DagobangRouterUpgradeModule = buildModule("DagobangRouterUpgradeModule", (m) => {

  const network = getSelectedNetwork();

  const args = getDeploymentArgs(network).DagobangProxy;
  const proxyAddress = args.proxyAddress;
  const upgradeCallData = args.upgradeCallData;

  const routerProxy = m.contractAt("DagobangProxy", proxyAddress, { id: "DagobangRouterProxy" });
  const routerImplementation = m.contract("DagobangRouter");

  m.call(routerProxy, "upgradeToAndCall", [routerImplementation, upgradeCallData], {
    after: [routerImplementation],
    id: "DagobangRouterProxy_upgradeToAndCall",
  });

  return {
    routerImplementation,
    routerProxy,
  };
});

export default DagobangRouterUpgradeModule;
