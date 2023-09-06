const { ethers } = require('hardhat')
const { writeFileSync } = require('fs')

const cakePool = '0x683433ba14e8F26774D43D3E90DA6Dd7a22044Fe';
const cakeToken = '0xFa60D973F7642B748046464e165A65B7323b0DEE';

async function main() {
    const provider = new ethers.providers.JsonRpcProvider("https://long-tiniest-orb.bsc-testnet.discover.quiknode.pro/424b617c99085c11c11e920159102dc20977a0d4/");
    
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);
  
    console.log("Account balance:", (await deployer.getBalance()).toString());
    
    console.log("deploying fixer...")
    const Fixer= await ethers.getContractFactory('Fixer2');
    const fixer = await Fixer.deploy()
    .then((f) => f.deployed())
    console.log("deployed fixer with address: ", fixer.address);

    writeFileSync(
        'deploy.json',
        JSON.stringify(
          {
            fixer: fixer.address,
          },
          null,
          1
        )
      )
    
      console.log(
        `fixer: ${fixer.address}`
      )
  }
  
  if (require.main === module) {
    main()
      .then(() => process.exit(0))
      .catch((error) => {
        console.error(error)
        process.exit(1)
      })
  }