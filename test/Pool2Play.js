// import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
// import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
// import { expect } from "chai";
//import { ethers } from "hardhat";
const {ethers} = require("hardhat");
const { expect } = require("chai");
const { cakeTokenAbi } = require('../abi/cakeToken')

const cakeTokenAddress= '0x5FbDB2315678afecb367f032d93F642f64180aa3'
const masterChefAddress= '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512'
const masterChefV2Address= '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

describe("Pool2Play Test", async function(){
    var owner;
    var user;
    var treasury;
    var operator;
    var cakeToken;
    var tournament;
    var minDepositAmount = ethers.BigNumber.from("10000000000000");
    let fixer, cakePool, tournamentAddress;

    beforeEach(async () => {

        [owner, user, treasury, operator] = await ethers.getSigners();

        const CakePool = await ethers.getContractFactory("CakePool")
        cakePool = await CakePool.deploy(cakeTokenAddress, masterChefV2Address, owner.address, treasury.address, operator.address, 0)

        const Fixer = await ethers.getContractFactory("Fixer2")
        fixer = await Fixer.deploy();

        cakeToken = await ethers.getContractAt(cakeTokenAbi, cakeTokenAddress, owner)
        //console.log("cakePool address: ", cakePool.address)
        //console.log("fixer address: ", fixer.address)
    });

    it("Should be able to create new Tournament", async function() {
        const block = await ethers.provider.getBlock("latest")
        const currentTimeStamp = block.timestamp;

        const createTournamentTx = await fixer.createTournament(cakePool.address, cakeTokenAddress, cakeTokenAddress, currentTimeStamp+100, currentTimeStamp+200, minDepositAmount);
        const receipt = await createTournamentTx.wait() 
        //console.log(createTournamentTx)
        const txBlock = await ethers.provider.getBlock(createTournamentTx.blockNumber)
        //console.log("block: ", txBlock)
        const txTimeStamp = await txBlock.timestamp

        const events = await receipt.events;
        events.forEach((event) => {
            if(event.event == 'TournamentCreated') {
                tournamentAddress = event.args.tournamentAddress;
            }
        })

        //console.log(await fixer.tournament(0))
        //console.log(await fixer.getTournamentInfo(0))
        await expect(createTournamentTx).to.emit(fixer, "TournamentCreated2").withArgs([cakePool.address, owner.address, currentTimeStamp+100, currentTimeStamp+200, txTimeStamp, cakeTokenAddress, cakeTokenAddress, minDepositAmount, 0])
        //await expect(fixer.getTournamentInfo(0))
    })

    it.only("Should be able to deposit", async function() {
        const block = await ethers.provider.getBlock("latest")
        const currentTimeStamp = block.timestamp;

        const createTournamentTx = await fixer.createTournament(cakePool.address, cakeTokenAddress, cakeTokenAddress, currentTimeStamp+100, currentTimeStamp+200, minDepositAmount);
        const receipt = await createTournamentTx.wait() 
        const events = await receipt.events;
        events.forEach((event) => {
            if(event.event == 'TournamentCreated') {
                tournamentAddress = event.args.tournamentAddress;
            }
        })
        
        const amount = ethers.BigNumber.from("1000000000000000000")
        console.log(owner.address, amount)
        await cakeToken.mint(user.address, amount)
        await cakeToken.connect(user).approve(tournamentAddress, amount)
        await cakeToken.connect(user).approve(cakePool.address, amount)
        //await cakeToken.connect(user).approve(fixer.address, amount)
        await cakePool.deposit(amount, 604800)
        //const depositTx = await fixer.connect(user).deposit(0, amount, 0)

        //await expect(depositTx).to.emit(depositTx, "Deposit").withArgs(user.address, 0, 0, amount)
    })
})