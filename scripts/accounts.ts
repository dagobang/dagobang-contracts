type NetworkType = "mainnet" | "testnet" | "local" | "hardhat";
const getAccounts = (type: NetworkType) => {

    let accounts = [];

    switch (type) {
        case "mainnet":
            accounts = [
                process.env.PROD_DEPLOYER!,
                process.env.PROD_CALLER!,
                process.env.PROD_CALLER2!,
                process.env.PROD_CALLER3!];
            break;
        case "testnet":
            // testnet
            accounts = [
                process.env.TEST_DEPLOYER!,
                process.env.TEST_CALLER!,
                process.env.TEST_CALLER2!,
                process.env.TEST_CALLER3!];
            break;
        default:
            // local
            accounts = [
                process.env.LOCAL_DEPLOYER!,
                process.env.LOCAL_CALLER!,
                process.env.LOCAL_CALLER2!,
                process.env.LOCAL_CALLER3!
            ];
            break;
    }
    return accounts;
};


export default getAccounts