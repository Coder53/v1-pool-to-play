import { expect } from 'chai';
import { deployMockContract, MockContract } from 'ethereum-waffle';
import { utils, Contract, ContractFactory, Signer, Wallet, BigNumber } from 'ethers';
import { ethers, artifacts } from 'hardhat';
import { Interface } from 'ethers/lib/utils';

const { getSigners, provider } = ethers;
const { parseEther: toWei } = utils;

const increaseTime = async (time: number) => {
    await provider.send('evm_increaseTime', [ time ]);
    await provider.send('evm_mine', []);
};

function printBalances(balances: any) {
    balances = balances.filter((balance: any) => balance.timestamp != 0)
    balances.map((balance: any) => {
        console.log(`Balance @ ${balance.timestamp}: ${ethers.utils.formatEther(balance.balance)}`)
    })
}

describe('TsunamiDrawCalculator', () => {
    let drawCalculator: Contract; let ticket: MockContract;
    let wallet1: any;
    let wallet2: any;
    let wallet3: any;

    
    let draw: any
    const encoder = ethers.utils.defaultAbiCoder

    beforeEach(async () =>{
        [ wallet1, wallet2, wallet3 ] = await getSigners();
        const drawCalculatorFactory = await ethers.getContractFactory("TsunamiDrawCalculatorHarness")
        drawCalculator = await drawCalculatorFactory.deploy()

        let ticketArtifact = await artifacts.readArtifact('ITicket')
        ticket = await deployMockContract(wallet1, ticketArtifact.abi)

        const matchCardinality = 8
        const prizeRange = 10
        await drawCalculator.initialize(ticket.address, matchCardinality, [ethers.utils.parseEther("0.8"), ethers.utils.parseEther("0.2")], prizeRange)

    })

    describe('admin functions', ()=>{
        it('onlyOwner should set matchCardinality', async ()=>{
            expect(await drawCalculator.setMatchCardinality(5)).
                to.emit(drawCalculator, "MatchCardinalitySet").
                withArgs(5)
            await expect(drawCalculator.connect(wallet2).setMatchCardinality(5)).to.be.reverted
        })

        it('onlyOwner should set range', async ()=>{
            expect(await drawCalculator.setNumberRange(5)).
                to.emit(drawCalculator, "PrizeRangeSet").
                withArgs(5)
            await expect(drawCalculator.connect(wallet2).setNumberRange(5)).to.be.reverted
        })
        
        it('onlyOwner set prize distributions', async ()=>{
            expect(await drawCalculator.setPrizeDistribution([ethers.utils.parseEther("0.8"), ethers.utils.parseEther("0.2")])).
                to.emit(drawCalculator, "PrizeDistributionsSet")
            await expect(drawCalculator.connect(wallet2).setPrizeDistribution([ethers.utils.parseEther("0.8"), ethers.utils.parseEther("0.2")])).to.be.reverted
        })

        it('cannot set over 100pc of prize for distribution', async ()=>{
            await expect(drawCalculator.setPrizeDistribution([ethers.utils.parseEther("0.9"), ethers.utils.parseEther("0.2")])).to.be.revertedWith("sum of distributions too large")
        })
    })

    describe('getValueAtIndex()', ()=>{
        it('should return the value at 0 index with full range, no bias', async ()=>{
            const result = await drawCalculator.callStatic.getValueAtIndex("63","0","16")
            expect(result).to.equal(15)
        })
        it('should return the value at 1 index with full range, no bias', async ()=>{
            const result = await drawCalculator.callStatic.getValueAtIndex("63","1","15")
            expect(result).to.equal(3)
        })
        it('should return the value at 1 index with full range, no bias', async ()=>{
            const result = await drawCalculator.callStatic.getValueAtIndex("64","1","15")
            expect(result).to.equal(4)
        })
        it('should return the value at 0 index with half range', async ()=>{
            const result = await drawCalculator.callStatic.getValueAtIndex("63","0","7")
            expect(result).to.equal(1) // 15 % 7
        })
        it('should return the value at 0 index with 1 range', async ()=>{
            const result = await drawCalculator.callStatic.getValueAtIndex("63","0","1")
            expect(result).to.equal(0) // 15 % 1
        })
        it('should return the value at 0 index with half range', async ()=>{
            const result = await drawCalculator.callStatic.getValueAtIndex("63","0","10")
            expect(result).to.equal(5) // 15 % 10
        })
    })

    describe('calculate()', () => {
        it('should calculate and win grand prize', async () => {
            //function calculate(address user, uint256[] calldata randomNumbers, uint256[] calldata timestamps, uint256[] calldata prizes, bytes calldata data) external override view returns (uint256){

            const winningNumber = utils.solidityKeccak256(["address"], [wallet1.address])//"0x1111111111111111111111111111111111111111111111111111111111111111"
            // console.log("winningNumber in test", winningNumber)
            const winningRandomNumber = utils.solidityKeccak256(["bytes32", "uint256"],[winningNumber, 1])
            // console.log("winningRandomNumber in test", winningRandomNumber)

            const timestamp = 42
            const prizes = [utils.parseEther("100")]
            const pickIndices = encoder.encode(["uint256[][]"], [[["1"]]])
            const ticketBalance = utils.parseEther("10")

            await ticket.mock.getBalances.withArgs(wallet1.address, [timestamp]).returns([ticketBalance]) // (user, timestamp): balance

            expect(await drawCalculator.calculate(
                wallet1.address,
                [winningRandomNumber],
                [timestamp],
                prizes,
                pickIndices
            )).to.equal(utils.parseEther("80"))
            
            console.log("GasUsed for calculate(): ", (await drawCalculator.estimateGas.calculate(
                wallet1.address,
                [winningRandomNumber],
                [timestamp],
                prizes,
                pickIndices)).toString())
        })

        it('should calculate and win nothing', async () => {
            //function calculate(address user, uint256[] calldata winningRandomNumbers, uint256[] calldata timestamps, uint256[] calldata prizes, bytes calldata data)

            const winningNumber = utils.solidityKeccak256(["address"], [wallet2.address])
            // console.log("winningNumber in test", winningNumber)
            const userRandomNumber = utils.solidityKeccak256(["bytes32", "uint256"],[winningNumber, 1])
            console.log("userRandomNumber in test", userRandomNumber)

            const timestamp = 42
            const prizes = [utils.parseEther("100")]
            const pickIndices = encoder.encode(["uint256[][]"], [[["1"]]])
            const ticketBalance = utils.parseEther("10")

            await ticket.mock.getBalances.withArgs(wallet1.address, [timestamp]).returns([ticketBalance]) // (user, timestamp): balance

            expect(await drawCalculator.calculate(
                wallet1.address,
                [userRandomNumber],
                [timestamp],
                prizes,
                pickIndices
            )).to.equal(utils.parseEther("0"))
        })

        it.only('increasing the matchCardinality results in lower probability of a match', async () => {
            //function calculate(address user, uint256[] calldata winningRandomNumbers, uint256[] calldata timestamps, uint256[] calldata prizes, bytes calldata data)
            const timestamp = 42
            const prizes = [utils.parseEther("100")]
            const pickIndices = encoder.encode(["uint256[][]"], [[["1"]]])
            const ticketBalance = utils.parseEther("10")

            await ticket.mock.getBalances.withArgs(wallet1.address, [timestamp]).returns([ticketBalance]) // (user, timestamp): balance
            
            // increasing the distribution array length should make it easier to get a match
            await drawCalculator.setPrizeDistribution([
                ethers.utils.parseEther("0.2"),
                ethers.utils.parseEther("0.1"),
                ethers.utils.parseEther("0.1"),
                ethers.utils.parseEther("0.1")
            ])
            
            await drawCalculator.setMatchCardinality(6)
            await drawCalculator.setNumberRange(4)

            // let attemptsIndex = 0
            let resultingPrize :BigNumber = BigNumber.from("0")
            const winningRandomNumber = "0x3fa0adea2a0c897d68abddf4f91167acda84750ee4a68bf438860114c8592b35"
            resultingPrize = await drawCalculator.calculate(
                wallet1.address,
                [winningRandomNumber],
                [timestamp],
                prizes,
                pickIndices
            )
            expect(resultingPrize.gt("0"))

            // while(true){
            //     const randomWallet = ethers.Wallet.createRandom()
            //     const winningNumber = utils.solidityKeccak256(["address"], [randomWallet.address])
            //     const winningRandomNumber = utils.solidityKeccak256(["bytes32", "uint256"],[winningNumber, 1])
            //     // console.log(`attempt ${attemptsIndex} trying winningRandomNumber: ", ${winningRandomNumber}`)
            //     resultingPrize = await drawCalculator.calculate(
            //         wallet1.address,
            //         [winningRandomNumber],
            //         [timestamp],
            //         prizes,
            //         pickIndices
            //     )
                
            //     if(resultingPrize.gt("0")){
            //         console.log("found winning random number!", winningRandomNumber)
            //         console.log("resultingPrize ", resultingPrize.toString())
            //         break;
            //     }
            //     attemptsIndex++
            // }
            // expect(resultingPrize.gt("0"))
            
            // now increase cardinality 
            await drawCalculator.setMatchCardinality(7)
            const winningRandomNumber2 = "0x2bc1ef3324c77402eb23da42db0555cee36014b14e59c2b0713ee2aa03c1dafc"
            // let reattemptsIndex = 0
            let resultingPrize2 :BigNumber = BigNumber.from("0")
            resultingPrize2 = await drawCalculator.calculate(
                wallet1.address,
                [winningRandomNumber],
                [timestamp],
                prizes,
                pickIndices
            )
            expect(resultingPrize2.gt("0"))

            // while(true){
            //     const randomWallet = ethers.Wallet.createRandom()
            //     const winningNumber = utils.solidityKeccak256(["address"], [randomWallet.address])
            //     const winningRandomNumber = utils.solidityKeccak256(["bytes32", "uint256"],[winningNumber, 1])
            //     // console.log(`test2: attempt ${reattemptsIndex} trying winningRandomNumber: ", ${winningRandomNumber}`)
            //     resultingPrize2 = await drawCalculator.calculate(
            //         wallet1.address,
            //         [winningRandomNumber],
            //         [timestamp],
            //         prizes,
            //         pickIndices
            //     )
                
            //     if(resultingPrize2.gt("0")){
            //         console.log("found winning random number!", winningRandomNumber)
            //         console.log("resultingPrize ", resultingPrize.toString())
            //         break;
            //     }
            //     reattemptsIndex++
            // }
            // console.log("attemptsIndex: ", attemptsIndex)
            // console.log("reattemptsIndex: ", reattemptsIndex)
            

            // expect(reattemptsIndex).to.be.greaterThan(attemptsIndex)
        })

        // probabalisitc test -- wrap in re-try block
        it('increasing the prize range results in lower probability of matches', async () => {
            //function calculate(address user, uint256[] calldata winningRandomNumbers, uint256[] calldata timestamps, uint256[] calldata prizes, bytes calldata data)
            const timestamp = 42
            const prizes = [utils.parseEther("100")]
            const pickIndices = encoder.encode(["uint256[][]"], [[["1"]]])
            const ticketBalance = utils.parseEther("10")

            await ticket.mock.getBalances.withArgs(wallet1.address, [timestamp]).returns([ticketBalance]) // (user, timestamp): balance
            
            // increasing the distribution array length should make it easier to get a match
            await drawCalculator.setPrizeDistribution([
                ethers.utils.parseEther("0.2"),
                ethers.utils.parseEther("0.1"),
                ethers.utils.parseEther("0.1"),
                ethers.utils.parseEther("0.1")
            ])
            
            await drawCalculator.setMatchCardinality(5)
            await drawCalculator.setNumberRange(4)

            let attemptsIndex = 0
            let resultingPrize :BigNumber = BigNumber.from("0")
            while(true){
                const randomWallet = ethers.Wallet.createRandom()
                const winningNumber = utils.solidityKeccak256(["address"], [randomWallet.address])
                const winningRandomNumber = utils.solidityKeccak256(["bytes32", "uint256"],[winningNumber, 1])
                console.log(`attempt ${attemptsIndex} trying winningRandomNumber: ", ${winningRandomNumber}`)
                resultingPrize = await drawCalculator.calculate(
                    wallet1.address,
                    [winningRandomNumber],
                    [timestamp],
                    prizes,
                    pickIndices
                )
                
                if(resultingPrize.gt("0")){
                    console.log("found winning random number!")
                    console.log("resultingPrize ", resultingPrize.toString())
                    break;
                }
                attemptsIndex++
            }
            expect(resultingPrize.gt("0"))

            // now increase prize range 
            await drawCalculator.setNumberRange(6) // this means 6 bits of the number are available for matching

            let reattemptsIndex = 0
            let resultingPrize2 :BigNumber = BigNumber.from("0")
            while(true){
                const randomWallet = ethers.Wallet.createRandom()
                const winningNumber = utils.solidityKeccak256(["address"], [randomWallet.address])
                const winningRandomNumber = utils.solidityKeccak256(["bytes32", "uint256"],[winningNumber, 1])
                console.log(`test2: attempt ${reattemptsIndex} trying winningRandomNumber: ", ${winningRandomNumber}`)
                resultingPrize2 = await drawCalculator.calculate(
                    wallet1.address,
                    [winningRandomNumber],
                    [timestamp],
                    prizes,
                    pickIndices
                )
                
                if(resultingPrize2.gt("0")){
                    console.log("found winning random number!")
                    console.log("resultingPrize ", resultingPrize.toString())
                    break;
                }
                reattemptsIndex++
            }
            console.log("attemptsIndex: ", attemptsIndex)
            console.log("reattemptsIndex: ", reattemptsIndex)
            

            expect(reattemptsIndex).to.be.greaterThan(attemptsIndex)
        })
    });
})
