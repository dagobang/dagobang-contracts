import { getSelectedNetwork } from "@/utils/network.js";
import { getDeploymentArgs } from "@/utils/readDeployment.js";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DagobangRouterHyperUpgradeModule = buildModule("DagobangRouterHyperUpgradeModule", (m) => {
  const network = getSelectedNetwork();
  const releaseTagDefault = process.env.HYPER_ROUTER_RELEASE_TAG || process.env.ROUTER_RELEASE_TAG || "latest";
  m.getParameter(
    "releaseTag",
    releaseTagDefault,
  );
  const releaseTagId = String(releaseTagDefault).replace(/[^A-Za-z0-9_]/g, "_");
  const config = getDeploymentArgs(network);
  const args = config.DagobangProxyHyper;
  const proxyAddress = args.proxyAddress;
  const upgradeCallData = args.upgradeCallData;
  const admin = m.getAccount(1);

  const routerProxy = m.contractAt("DagobangProxy", proxyAddress, { id: "DagobangRouterHyperProxy" });
  const routerImplementation = m.contract("DagobangRouterHyper", [], {
    id: `DagobangRouterHyper_${releaseTagId}`,
  });

  m.call(routerProxy, "upgradeToAndCall", [routerImplementation, upgradeCallData], {
    after: [routerImplementation],
    from: admin,
    id: `DagobangRouterHyperProxy_upgradeToAndCall_${releaseTagId}`,
  });

  return {
    routerImplementation,
    routerProxy,
  };
});

export default DagobangRouterHyperUpgradeModule;
