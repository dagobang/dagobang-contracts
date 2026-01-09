import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "ethers";

const MocksModule = buildModule("MocksModule", (m) => {
  // Mocks USDT
  const mockUSDT = m.contract("MockUSDT");
  for (let i = 0; i < 2; i++) {
    m.call(mockUSDT, "mint", [m.getAccount(i), parseEther("10000")], {
      after: [mockUSDT],
      id: `mockUSDT_mint_${i}`,
    });
  }

  // Mocks BinanceLife
  const mockBinanceLife = m.contract("MockBinanceLife", [m.getAccount(0)]);
  m.call(mockBinanceLife, "init", ["币安人生", "币安人生", parseEther("100000000")], {
    after: [mockBinanceLife],
    id: `mockBinanceLife_init`,
  });
  for (let i = 0; i < 2; i++) {
    m.call(mockBinanceLife, "mint", [m.getAccount(i), parseEther("10000")], {
      after: [mockBinanceLife],
      id: `mockBinanceLife_mint_${i}`,
    });
  }

  return {
    mockUSDT,
    mockBinanceLife,
  };
});

export default MocksModule;
