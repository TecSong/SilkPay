// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  // const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  // const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
  const _arbitrator = '0x47D7F6B196a58e08B70cfc7066901faca9863e52';
  const _gracePeriod = 300;

  // const lockedAmount = hre.ethers.utils.parseEther("0.0001");

  const SilkPayV1 = await hre.ethers.getContractFactory("SilkPayV1");
  const SILKPAYV1 = await SilkPayV1.deploy(_arbitrator, _gracePeriod);

  await SILKPAYV1.deployed();

  console.log(
    `SilkPayV1 deployed to ${SILKPAYV1.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
