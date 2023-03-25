const hre = require("hardhat");

async function main() {
  const lockedAmount = hre.ethers.utils.parseEther("1");

  const Arbitrator = await hre.ethers.getContractFactory("SilkArbitrator");
  const arbitrator = await Arbitrator.deploy(15, { value: lockedAmount });

  await arbitrator.deployed();

  console.log(
    `Lock with 1 ETH and unlock timestamp ${unlockTime} deployed to ${lock.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
