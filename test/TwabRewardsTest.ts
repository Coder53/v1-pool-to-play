import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("TwabRewards Test", async function(){
    var signer;
    var user;
    var cakeToken;
    var tournament;

    beforeEach(async () => {

        [signer, user] = await ethers.getSigners();

        cakeToken = await ethers.getContractFactory("TwabRewards")


    });

    it("Should be ok", async function() {
        console.log("test");
    })
})