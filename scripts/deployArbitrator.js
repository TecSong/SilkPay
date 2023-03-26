const { ethers } = require("hardhat");
const hre = require("hardhat");

async function main() {
  const Arbitrator = await hre.ethers.getContractFactory("SilkArbitrator");
  const arbitrator = await Arbitrator.deploy(15, [10,10,10,10]);

  await arbitrator.deployed();

  console.log(
    `Arbitrator with 15% fee deployed to ${arbitrator.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
