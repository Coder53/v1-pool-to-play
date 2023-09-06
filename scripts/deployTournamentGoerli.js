const { ethers } = require("hardhat");
const { writeFileSync } = require("fs");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

//const apeCoinStaking = "0x5954aB967Bc958940b7EB73ee84797Dc8a2AFbb9";
//const apeToken = "0x4d224452801ACEd8B2F0aebE155379bb5D594381";
let apeCoinStaking, apeCoin;

async function main() {
  // const provider = new ethers.providers.JsonRpcProvider(
  //   "https://eth-goerli.g.alchemy.com/v2/M159zPGUIGLuBugqPlZrIIzvSBA93hfz"
  // );

  const provider = new ethers.providers.JsonRpcProvider(
    "https://eth-sepolia.g.alchemy.com/v2/n-ApUQvituG3OHEsgPNAerd3eER1PxU-"
  );

  const [deployer] = await ethers.getSigners();
  const apeCoinStakingAllocation = ethers.BigNumber.from(
    "100000000000000000000000000"
  );

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  //   console.log("deploying apeCoin...");
  //   const ApeCoin = await ethers.getContractFactory("SimpleToken");
  //   const totalSupply = ethers.BigNumber.from("1000000000000000000000000000");
  //   apeCoin = await ApeCoin.deploy("ApeCoin", "APE", totalSupply);
  //   console.log("deployed apeCoin with address: ", apeCoin.address);

  //   console.log("deploying apeCoinStaking...");
  //   const ApeCoinStaking = await ethers.getContractFactory("ApeCoinStaking");
  //   apeCoinStaking = await ApeCoinStaking.deploy(
  //     apeCoin.address,
  //     "0x5954aB967Bc958940b7EB73ee84797Dc8a2AFbb9",
  //     "0x5954aB967Bc958940b7EB73ee84797Dc8a2AFbb9",
  //     "0x5954aB967Bc958940b7EB73ee84797Dc8a2AFbb9"
  //   );
  //   console.log("deployed apeCoinStaking with address: ", apeCoinStaking.address);

  console.log("deploying tournament...");
  const blockNumber = await ethers.provider.getBlockNumber();
  const block = await ethers.provider.getBlock(blockNumber);
  const timestamp = block.timestamp;
  const minStake = ethers.BigNumber.from("10000000000000");

  const Tournament = await ethers.getContractFactory("P2P");
  const tournament = await Tournament.deploy(
    "0x628fedF5Be49a3acF7319d9f58338454CE0380a9",
    "0x628fedF5Be49a3acF7319d9f58338454CE0380a9",
    timestamp,
    timestamp + 100,
    minStake,
    deployer.address,
    deployer.address,
    deployer.address
  ).then((f) => f.deployed());
  console.log("deployed tournament with address: ", tournament.address);

  //Add time range
  let amount = ethers.BigNumber.from("4807692307692307692307");
  //await apeCoinStaking.addTimeRange(0, amount, 1670864400, 1678726800, 0);
  amount = ethers.BigNumber.from("4076086956521739130434");
  //await apeCoinStaking.addTimeRange(0, amount, 1678726800, 1686675600, 0);

  //   await apeCoin
  //     .connect(deployer)
  //     .approve(apeCoinStaking.address, apeCoinStakingAllocation);

  //await apeCoin.transfer(apeCoinStaking.address, apeCoinStakingAllocation);
  //await apeCoin.connect(deployer).transfer(user.address, depositApeCoinAmount);

  writeFileSync(
    "deploy.json",
    JSON.stringify(
      {
        //apeCoin: apeCoin.address,
        //apeCoinStaking: apeCoinStaking.address,
        tournament: tournament.address,
      },
      null,
      1
    )
  );

  const args = [
    "0xD8F043351800EFeE2d385Be32b6CB623EBaF747B",
    "0x628fedF5Be49a3acF7319d9f58338454CE0380a9",
    "0x628fedF5Be49a3acF7319d9f58338454CE0380a9",
    timestamp,
    timestamp + 100,
    minStake,
    deployer.address,
    0,
    deployer.address,
  ];

  const argsFileContent = `module.exports = ${JSON.stringify(args)};`;

  writeFileSync("args.js", argsFileContent);

  console.log(
    `apeCoin: ${"0xD8F043351800EFeE2d385Be32b6CB623EBaF747B"} \n apeCoinStaking: ${"0xD8F043351800EFeE2d385Be32b6CB623EBaF747B"} \n tournament: ${
      tournament.address
    } `
  );
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
