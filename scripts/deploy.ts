import { ethers, run } from "hardhat";

const VRF_COORDINATOR = "0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed";
const SUBSCRIPTION_ID = 456;
const KEY_HASH =
  "0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f";
const GAS_LIMIT = "500000";
async function main() {
  const Raffle = await ethers.getContractFactory("Raffle");
  const deployedRaffleContract = await Raffle.deploy(
    VRF_COORDINATOR,
    SUBSCRIPTION_ID,
    KEY_HASH,
    600,
    GAS_LIMIT
  );

  await deployedRaffleContract.deployed();

  await sleep(100000);

  console.log("Contract Address:", deployedRaffleContract.address);

  await run("verify:verify", {
    address: deployedRaffleContract.address,
    constructorArguments: [
      VRF_COORDINATOR,
      SUBSCRIPTION_ID,
      KEY_HASH,
      600,
      GAS_LIMIT,
    ],
  });
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    // eslint-disable-next-line no-process-exit
    process.exit(1);
  });
