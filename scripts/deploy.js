// Example deployment script. Out of the box it deploys the Token contract;
// swap in any of the others by changing the factory name and constructor args.
//
//   npx hardhat run scripts/deploy.js                   -> local network
//   npx hardhat run scripts/deploy.js --network sepolia -> Sepolia testnet
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying from account:", deployer.address);

  // Token(name, symbol, maxSupply, initialMint) — tweak these to taste.
  const Token = await ethers.getContractFactory("Token");
  const token = await Token.deploy("My Token", "MYT", 1_000_000, 1000);
  await token.waitForDeployment();

  console.log("Token deployed to:", await token.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
