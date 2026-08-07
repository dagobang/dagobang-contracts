import { getSelectedNetwork } from "@/utils/network.js";
import { getDeploymentArgs } from "@/utils/readDeployment.js";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DagobangRouterUpgradeModule = buildModule("DagobangRouterUpgradeModule", (m) => {

  const network = getSelectedNetwork();
  const zeroAddress = "0x0000000000000000000000000000000000000000";
  const ownerAccount = m.getAccount(0);
  const releaseTagDefault = process.env.BSC_ROUTER_RELEASE_TAG || process.env.ROUTER_RELEASE_TAG || "latest";
  m.getParameter(
    "releaseTag",
    releaseTagDefault,
  );
  const releaseTagId = String(releaseTagDefault).replace(/[^A-Za-z0-9_]/g, "_");

  const args = getDeploymentArgs(network).DagobangProxy;
  const routerArgs = getDeploymentArgs(network).DagobangRouter;
  const proxyAddress = args.proxyAddress;
  const upgradeCallData = args.upgradeCallData;
  const flapPortal = m.getParameter("flapPortal", routerArgs.flapPortal ?? zeroAddress);
  const admin = m.getAccount(1);

  const routerProxy = m.contractAt("DagobangProxy", proxyAddress, { id: "DagobangRouterProxy" });
  const router = m.contractAt("DagobangRouter", proxyAddress, { id: "DagobangRouterProxyAsRouter" });
  const flapSwapLib = m.library("FlapSwapLib", { id: `FlapSwapLib_${releaseTagId}` });
  const fourMemeSwapLib = m.library("FourMemeSwapLib", { id: `FourMemeSwapLib_${releaseTagId}` });
  const lunaSwapLib = m.library("LunaSwapLib", { id: `LunaSwapLib_${releaseTagId}` });
  const printrSwapLib = m.library("PrintrSwapLib", { id: `PrintrSwapLib_${releaseTagId}` });
  const openFourSwapLib = m.library("OpenFourSwapLib", { id: `OpenFourSwapLib_${releaseTagId}` });
  const likwidSwapLib = m.library("LikwidSwapLib", { id: `LikwidSwapLib_${releaseTagId}` });
  const routerImplementation = m.contract("DagobangRouter", [], {
    id: `DagobangRouter_${releaseTagId}`,
    libraries: {
      FlapSwapLib: flapSwapLib,
      FourMemeSwapLib: fourMemeSwapLib,
      LunaSwapLib: lunaSwapLib,
      PrintrSwapLib: printrSwapLib,
      OpenFourSwapLib: openFourSwapLib,
      LikwidSwapLib: likwidSwapLib,
    },
  });

  m.call(routerProxy, "upgradeToAndCall", [routerImplementation, upgradeCallData], {
    after: [routerImplementation],
    from: admin,
    id: `DagobangRouterProxy_upgradeToAndCall_${releaseTagId}`,
  });
  m.call(router, "setFlapPortal", [flapPortal], {
    after: [routerImplementation],
    from: ownerAccount,
    id: `DagobangRouter_setFlapPortal_${releaseTagId}`,
  });

  return {
    routerImplementation,
    routerProxy,
  };
});

export default DagobangRouterUpgradeModule;
