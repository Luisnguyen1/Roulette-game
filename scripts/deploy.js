const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // Deploy Roulette first without AccountManager address
  console.log("Deploying Roulette...");
  const Roulette = await hre.ethers.getContractFactory("Roulette");
  const roulette = await Roulette.deploy("0x0000000000000000000000000000000000000000");
  console.log("Waiting for Roulette deployment...");
  await roulette.waitForDeployment();
  const rouletteAddress = await roulette.getAddress();
  console.log("Roulette deployed to:", rouletteAddress);

  // Deploy AccountManager with Roulette address
  console.log("Deploying AccountManager...");
  const AccountManager = await hre.ethers.getContractFactory("AccountManager");
  const accountManager = await AccountManager.deploy(rouletteAddress);
  console.log("Waiting for AccountManager deployment...");
  await accountManager.waitForDeployment();
  const accountManagerAddress = await accountManager.getAddress();
  console.log("AccountManager deployed to:", accountManagerAddress);

  // Now update Roulette's AccountManager address
  console.log("Setting AccountManager address in Roulette...");
  const setAccountManagerTx = await roulette.setAccountManager(accountManagerAddress);
  await setAccountManagerTx.wait();
  console.log("AccountManager address set in Roulette contract");

  // Write contract addresses to config file
  const fs = require("fs");
  const config = {
    roulette: rouletteAddress,
    accountManager: accountManagerAddress
  };

  fs.writeFileSync(
    "./frontend/js/contracts-config.js",
    `export const CONTRACT_ADDRESSES = ${JSON.stringify(config, null, 2)};`
  );

  // Log final confirmation
  console.log("Deployment completed!");
  console.log("Contract addresses saved to frontend/js/contracts-config.js");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });