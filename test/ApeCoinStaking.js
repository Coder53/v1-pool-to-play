const { ethers } = require("hardhat");
const { expect } = require("chai");
const { cakeTokenAbi } = require("../abi/cakeToken");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { extendEnvironment } = require("hardhat/config");

describe("ApeCoin Staking", async function () {
  let owner,
    user,
    bayc,
    mayc,
    bakc,
    tournament,
    apeCoin,
    apeCoinStaking,
    treasury,
    player1,
    player2,
    player3,
    player4,
    player5,
    placement,
    currentTimestamp,
    doneDepositTime;

  //const currentDate = new Date();
  //const currentTimestamp = currentDate.getTime();
  const minStake = ethers.BigNumber.from("10000000000000");
  const apeCoinStakingAllocation = ethers.BigNumber.from(
    "100000000000000000000000000"
  );
  const depositApeCoinAmount = ethers.BigNumber.from("50000000000000000000000");
  const testAmount = ethers.BigNumber.from("1000");

  beforeEach(async () => {
    [
      owner,
      user,
      bayc,
      mayc,
      bakc,
      treasury,
      lockStaking,
      player1,
      player2,
      player3,
      player4,
      player5,
      player,
      players,
    ] = await ethers.getSigners();

    currentTimestamp = await time.latest();

    const ApeCoin = await ethers.getContractFactory("SimpleToken");
    const totalSupply = ethers.BigNumber.from("1000000000000000000000000000");
    apeCoin = await ApeCoin.deploy("ApeCoin", "APE", totalSupply);

    const ApeCoinStaking = await ethers.getContractFactory("ApeCoinStaking");
    apeCoinStaking = await ApeCoinStaking.deploy(
      apeCoin.address,
      bayc.address,
      mayc.address,
      bakc.address
    );

    const Tournament = await ethers.getContractFactory("Tournament2ApeCoin");
    tournament = await Tournament.deploy(
      apeCoinStaking.address,
      apeCoin.address,
      apeCoin.address,
      currentTimestamp,
      currentTimestamp + 100,
      minStake,
      owner.address,
      0,
      treasury.address
    );

    const LockStaking = await ethers.getContractFactory("LockStaking");
    lockStaking = await LockStaking.deploy(tournament.address, apeCoin.address);

    await tournament.setLockStaking(lockStaking.address);

    //Add time range
    let amount = ethers.BigNumber.from("4807692307692307692307");
    await apeCoinStaking.addTimeRange(0, amount, 1670864400, 1678726800, 0);
    amount = ethers.BigNumber.from("4076086956521739130434");
    await apeCoinStaking.addTimeRange(0, amount, 1678726800, 1686675600, 0);

    await apeCoin
      .connect(owner)
      .approve(apeCoinStaking.address, apeCoinStakingAllocation);

    await apeCoin.transfer(apeCoinStaking.address, apeCoinStakingAllocation);
    await apeCoin.connect(owner).transfer(user.address, depositApeCoinAmount);
    players = [player1, player2, player3, player4, player5];

    player = [
      player1.address,
      player2.address,
      player3.address,
      player4.address,
      player5.address,
    ];
    placement = [1, 2, 3, 4, 5];

    await DepositPlayers();
  });

  it("Should be able to deposit ApeCoin", async function () {
    // console.log("owner: ", owner.address)
    // console.log("spender: ", apeCoinStaking.address)
    // console.log("allowance: ", await apeCoin.allowance(owner.address, apeCoinStaking.address))
    // console.log("amount: ", testAmount)

    //await apeCoin.connect(owner).approve(user.address, depositApeCoinAmount)

    await apeCoin
      .connect(user)
      .approve(apeCoinStaking.address, depositApeCoinAmount);
    await apeCoinStaking
      .connect(user)
      .depositApeCoin(depositApeCoinAmount, tournament.address);
    //console.log(await apeCoinStaking.addressPosition(tournament.address));

    //await expect(await apeCoinStaking.addressPosition(user.address).stakedAmount).to.equal(depositApeCoinAmount)
  });

  it("Should be able to transfer ApeCoin using transferFrom", async function () {
    const testAmount = ethers.BigNumber.from("1000");

    // Approve allowance for the user
    await apeCoin.connect(owner).approve(user.address, testAmount);
    // console.log("owner: ", owner.address);
    // console.log("spender: ", user.address);
    // console.log(
    //   "allowance: ",
    //   await apeCoin.allowance(owner.address, user.address)
    // );
    // console.log("amount: ", testAmount);

    // Transfer ApeCoin from owner to user using transferFrom
    await apeCoin
      .connect(user)
      .transferFrom(owner.address, user.address, testAmount);
  });

  it("Should be able to deposit ApeCoin through tournament", async function () {
    //await DepositPlayers();

    await expect(await tournament.totalStaked()).to.equal(
      depositApeCoinAmount.mul(players.length)
    );

    //console.log(await apeCoinStaking.addressPosition(tournament.address));
    // const stakedAmount = await apeCoinStaking.stakedTotal(tournament.address);
    // console.log(stakedAmount);

    const position = await apeCoinStaking.addressPosition(tournament.address);

    //console.log(position.stakedAmount);

    const totalStaked = await tournament.totalStaked();

    //console.log(`stakedAmount: ${stakedAmount}, totalStaked: ${totalStaked}`);
    await expect(position.stakedAmount).to.equal(
      await tournament.totalStaked()
    );
  });

  it("Should be able to withdraw ApeCoin through tournament", async function () {
    await apeCoin
      .connect(user)
      .approve(tournament.address, depositApeCoinAmount);

    await tournament.connect(user).deposit(depositApeCoinAmount);

    const apeCoinBalance = await apeCoin.balanceOf(user.address);

    await time.increaseTo(currentTimestamp + 200);

    //const pendingRewards = await tournament.getPendingRewards();

    await tournament.setTournamentPhase(2);
    await tournament.connect(user).withdraw(depositApeCoinAmount);

    await expect(await apeCoin.balanceOf(user.address)).to.equal(
      apeCoinBalance + depositApeCoinAmount
    );
  });

  it("Multiple players should be able to join a tournament", async function () {
    //await DepositPlayers();

    await expect(await tournament.totalStaked()).to.equal(
      depositApeCoinAmount.mul(players.length)
    );
  });

  it("Should be able to set player's placement", async function () {
    //await DepositPlayers();
    await time.increaseTo(currentTimestamp + 10000);
    await tournament.setTournamentPhase(2);

    await tournament.setPlayerPlacement(player, placement);

    await expect(
      await tournament.getPlacementByAddress(player1.address)
    ).to.equal(1);
    await expect(
      await tournament.getPlacementByAddress(player2.address)
    ).to.equal(2);
    await expect(
      await tournament.getPlacementByAddress(player3.address)
    ).to.equal(3);
  });

  it("Should be able to collect yield", async function () {
    //await DepositPlayers();
    await tournament.setPlayerPlacement(player, placement);
    const positionOld = await apeCoinStaking.addressPosition(
      tournament.address
    );

    await time.increaseTo(currentTimestamp + 10000);

    await tournament.setTournamentPhase(2);
    const apeCoinBalance = await apeCoin.balanceOf(tournament.address);
    const positionNew = await apeCoinStaking.addressPosition(
      tournament.address
    );
    //console.log("positionNew: ", positionNew);
    const pendingRewards = await tournament.getPendingRewards();
    //console.log("pendingRewards: ", pendingRewards);
    await tournament.collectYieldAndDistributeRewards();
    //console.log("pendingRewards: ", pendingRewards);
    const collectYield =
      (await apeCoin.balanceOf(tournament.address)) - apeCoinBalance;
    //console.log("collectedYield: ", collectYield);
  });

  it("Should be able to set placement rewards", async function () {
    const placementRewards = [50, 25, 15, 5];
    await tournament.setPlacementRewardPercentage(placementRewards);
    const rewards = await tournament.getPlacementRewardPercentage();
    const placement = [
      ethers.BigNumber.from("0"),
      ethers.BigNumber.from("50"),
      ethers.BigNumber.from("25"),
      ethers.BigNumber.from("15"),
      ethers.BigNumber.from("5"),
    ];
    for (let i = 0; i < rewards.length; i++) {
      //console.log(rewards[i]);
      //console.log(placement[i]);
      expect(rewards[i].toString()).to.equal(placement[i].toString());
    }
  });

  it("Should distribute reward correctly", async function () {
    await time.increaseTo(currentTimestamp + 10000);

    await tournament.setPlayerPlacement(player, placement);

    const placementRewards = [50, 25, 15, 5];
    await tournament.setPlacementRewardPercentage(placementRewards);

    await tournament.setTournamentPhase(2);

    const rewards = await tournament.getPlacementRewardPercentage();
    console.log(rewards);

    await tournament.collectYieldAndDistributeRewards();

    const prizePool = await tournament.prizePool();

    for (let i = 0; i < players.length - 1; i++) {
      const playerRewards = await tournament.getUserRewards(players[i].address);

      const share = playerRewards
        .mul(ethers.BigNumber.from("100"))
        .div(prizePool)
        .toString();
      console.log(rewards[placement[i]]);
      await expect(share).to.equal(rewards[placement[i]].toString());
    }
  });

  it("Should be able to reset tournament: ", async function () {
    const newTime = currentTimestamp + 10000;
    await time.increaseTo(newTime);

    await tournament.setPlayerPlacement(player, placement);

    const placementRewards = [50, 25, 15, 5];
    await tournament.setPlacementRewardPercentage(placementRewards);

    await tournament.setTournamentPhase(2);

    await tournament.collectYieldAndDistributeRewards();

    await tournament.newTournament(newTime + 100, newTime + 500, minStake);

    await expect(await tournament.totalStaked()).to.equal(
      depositApeCoinAmount.mul(players.length)
    );

    for (let i = 0; i < players.length; i++) {
      //console.log(await tournament.getPlacementByAddress(players[i].address));
      await expect(
        await tournament.getPlacementByAddress(players[i].address)
      ).to.equal(0);
    }

    const initialPhase = 0;
    const currentPhase = await tournament.currentPhase();
    expect(currentPhase).to.equal(initialPhase);
  });

  //Test twab stuff
  it("It should calculate correct TWAB", async function () {
    //console.log((await tournament.tournamentInfo()).createdAt);
    let newTime = currentTimestamp + 20000;
    await time.increaseTo(newTime);

    const newPlayer = await ethers.getSigner();
    await apeCoin
      .connect(owner)
      .transfer(newPlayer.address, depositApeCoinAmount);
    await apeCoin
      .connect(newPlayer)
      .approve(tournament.address, depositApeCoinAmount);
    await tournament.connect(newPlayer).deposit(depositApeCoinAmount);

    await time.increaseTo(newTime + 20);
    let latestTime = await time.latest();

    const player1Twab = await tournament.getAverageBalanceBetween(
      players[0].address,
      (
        await tournament.tournamentInfo()
      ).createdAt,
      //doneDepositTime,
      latestTime
    );

    const newPlayerTwab = await tournament.getAverageBalanceBetween(
      newPlayer.address,
      (
        await tournament.tournamentInfo()
      ).createdAt,
      //doneDepositTime,
      latestTime
    );

    const stakedAmount = await tournament.getTournamentPlayersInfoByAddress(
      newPlayer.address
    );
    //console.log("player1Twab: ", player1Twab);
    //console.log("newPlayerTwab: ", newPlayerTwab);
    //console.log("newPlayerStaked: ", stakedAmount.stakedAmount);
    await expect(player1Twab).to.be.greaterThan(newPlayerTwab);
  });

  it("Should be able to lock staking", async function () {
    const lockAmount = ethers.BigNumber.from("10000000000000000000000");
    await apeCoin.connect(owner).transfer(player1.address, lockAmount);
    await apeCoin.connect(player1).approve(lockStaking.address, lockAmount);

    await expect(
      tournament.connect(player1).lockDeposit(lockAmount)
    ).to.be.rejectedWith("can only be called by lockStaking contract");

    const lockTime = await time.latest();
    await lockStaking.connect(player1).lock(1, lockAmount);

    //cannot unlock
    //cannot withdraw from tournament
    //can unlock after finish locking duration
    //increased lockedAmount in tournament after deposit
    //decreased lockedAmount in tournament after withdrawLocked
    const playerInfo = await tournament.getTournamentPlayersInfoByAddress(
      player1.address
    );
    await expect(playerInfo.stakedAmount).to.equal(depositApeCoinAmount);
    await expect(playerInfo.lockedAmount).to.equal(lockAmount);
    await expect(lockStaking.connect(player1).unlock(1)).to.be.rejectedWith(
      "Not ready to unlock"
    );

    let newTime = lockTime + 7776010;
    await time.increaseTo(newTime);
    await tournament.setTournamentPhase(2);
    await expect(tournament.connect(player1).withdraw(depositApeCoinAmount)).to
      .not.be.reverted;
    await expect(
      tournament.connect(player1).withdraw(lockAmount)
    ).to.be.revertedWith("Nothing to withdraw");
    await expect(lockStaking.connect(player1).unlock(1)).to.not.be.reverted;
  });

  async function DepositPlayers() {
    for (let i = 0; i < players.length; i++) {
      const player = players[i];
      await apeCoin
        .connect(owner)
        .transfer(player.address, depositApeCoinAmount);
      await apeCoin
        .connect(player)
        .approve(tournament.address, depositApeCoinAmount);
      await tournament.connect(player).deposit(depositApeCoinAmount);
      //console.log(await tournament.totalStaked());
    }
    doneDepositTime = await time.latest();
  }
});
