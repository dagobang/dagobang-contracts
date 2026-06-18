import { getSelectedNetwork, isLocal } from "@/utils/network.js";
import { getDeploymentArgs } from "@/utils/readDeployment.js";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DagobangRouterDeployModule = buildModule("DagobangRouterDeployModule", (m) => {
  const network = getSelectedNetwork();

  let wNative: any;
  let v3Factory: any;
  if (isLocal()) {
    wNative = m.contract("MockWNative");
    v3Factory = m.contract("MockV3Factory");
  }
  else {
    const args = getDeploymentArgs(network).DagobangRouter;
    wNative = args.wNative;
    v3Factory = args.v3Factory;
  }

  const owner = m.getParameter("owner", m.getAccount(0));
  const admin = m.getParameter("admin", m.getAccount(1));
  const flapSwapLib = m.library("FlapSwapLib");
  const fourMemeSwapLib = m.library("FourMemeSwapLib");
  const lunaSwapLib = m.library("LunaSwapLib");
  const printrSwapLib = m.library("PrintrSwapLib");
  const openFourSwapLib = m.library("OpenFourSwapLib");
  const likwidSwapLib = m.library("LikwidSwapLib");
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

  const initData = m.encodeFunctionCall(routerImplementation, "initialize", [owner, wNative, v3Factory]);
  const routerProxy = m.contract("DagobangProxy", [routerImplementation, admin, initData], {
    id: "DagobangRouterProxy",
  });

  return {
    routerImplementation,
    routerProxy,
  };
});

export default DagobangRouterDeployModule;
