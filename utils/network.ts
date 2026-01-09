export const getSelectedNetwork = (): string => {
  const argv = process.argv || [];
  const idx = argv.indexOf("--network");
  if (idx !== -1 && idx + 1 < argv.length) {
    return argv[idx + 1];
  }
  const inline = argv.find((a) => a.startsWith("--network="));
  if (inline) {
    return inline.split("=")[1];
  }

  return "hardhat";
};

export const isLocal = (): boolean => {
  const name = getSelectedNetwork();
  return name === "hardhat" || name === "localhost" || name === "anvil" || name === "ganache";
};