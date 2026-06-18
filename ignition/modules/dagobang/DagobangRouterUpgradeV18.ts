import { getSelectedNetwork } from "@/utils/network.js";
import { getDeploymentArgs } from "@/utils/readDeployment.js";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DagobangRouterUpgradeV18Module = buildModule("DagobangRouterUpgradeV18Module", (m) => {
  const network = getSelectedNetwork();

  const args = getDeploymentArgs(network).DagobangProxy;
  const proxyAddress = args.proxyAddress;
  const upgradeCallData = args.upgradeCallData;

  const routerProxy = m.contractAt("DagobangProxy", proxyAddress, { id: "DagobangRouterProxy" });
  const flapSwapLib = m.library("FlapSwapLib", { id: "FlapSwapLib_V18" });
  const fourMemeSwapLib = m.library("FourMemeSwapLib", { id: "FourMemeSwapLib_V18" });
  const lunaSwapLib = m.library("LunaSwapLib", { id: "LunaSwapLib_V18" });
  const printrSwapLib = m.library("PrintrSwapLib", { id: "PrintrSwapLib_V18" });
  const openFourSwapLib = m.library("OpenFourSwapLib", { id: "OpenFourSwapLib_V18" });
  const likwidSwapLib = m.library("LikwidSwapLib", { id: "LikwidSwapLib_V18" });
  const routerImplementation = m.contract("DagobangRouter", [], {
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
    id: "DagobangRouterProxy_upgradeToAndCall_V18",
  });

  return {
    routerImplementation,
    routerProxy,
  };
});

export default DagobangRouterUpgradeV18Module;
