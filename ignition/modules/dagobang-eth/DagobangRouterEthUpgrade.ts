import { getSelectedNetwork } from "@/utils/network.js";
import { getDeploymentArgs } from "@/utils/readDeployment.js";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DagobangRouterEthUpgradeModule = buildModule("DagobangRouterEthUpgradeModule", (m) => {
  const network = getSelectedNetwork();
  const releaseTagDefault = process.env.ETH_ROUTER_RELEASE_TAG || process.env.ROUTER_RELEASE_TAG || "latest";
  m.getParameter(
    "releaseTag",
    releaseTagDefault,
  );
  const releaseTagId = String(releaseTagDefault).replace(/[^A-Za-z0-9_]/g, "_");
  const args = getDeploymentArgs(network).DagobangProxyEth;
  const proxyAddress = args.proxyAddress;
  const upgradeCallData = args.upgradeCallData;

  const routerProxy = m.contractAt("DagobangProxy", proxyAddress, { id: "DagobangRouterEthProxy" });
  const routerImplementation = m.contract("DagobangRouterEth", [], {
    id: `DagobangRouterEth_${releaseTagId}`,
  });

  m.call(routerProxy, "upgradeToAndCall", [routerImplementation, upgradeCallData], {
    after: [routerImplementation],
    id: `DagobangRouterEthProxy_upgradeToAndCall_${releaseTagId}`,
  });

  return {
    routerImplementation,
    routerProxy,
  };
});

export default DagobangRouterEthUpgradeModule;
