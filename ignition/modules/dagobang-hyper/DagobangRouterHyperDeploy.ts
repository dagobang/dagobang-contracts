import { getSelectedNetwork, isLocal } from "@/utils/network.js";
import { getDeploymentArgs } from "@/utils/readDeployment.js";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DagobangRouterHyperDeployModule = buildModule("DagobangRouterHyperDeployModule", (m) => {
  const network = getSelectedNetwork();

  let wNative: any;
  let hyperZap: any;
  let hyperBonding: any;
  let hyperUsdc: any;
  if (isLocal()) {
    wNative = m.contract("MockWNative");
    hyperZap = m.getParameter("hyperZap", "");
    hyperBonding = m.getParameter("hyperBonding", "");
    hyperUsdc = m.getParameter("hyperUsdc", "");
  } else {
    const args = getDeploymentArgs(network).DagobangRouterHyper;
    wNative = args.wNative;
    hyperZap = args.hyperZap;
    hyperBonding = args.hyperBonding;
    hyperUsdc = args.hyperUsdc;
  }

  const owner = m.getParameter("owner", m.getAccount(0));
  const admin = m.getParameter("admin", m.getAccount(1));
  const routerImplementation = m.contract("DagobangRouterHyper");

  const initData = m.encodeFunctionCall(routerImplementation, "initialize", [owner, wNative, hyperZap, hyperBonding, hyperUsdc]);
  const routerProxy = m.contract("DagobangProxy", [routerImplementation, admin, initData], {
    id: "DagobangRouterHyperProxy",
  });

  return {
    routerImplementation,
    routerProxy,
  };
});

export default DagobangRouterHyperDeployModule;
