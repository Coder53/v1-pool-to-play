// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
import "hardhat/console.sol";

import "./interfaces/IDrawCalculator.sol";
import "./interfaces/ITicket.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@pooltogether/uniform-random-number/contracts/UniformRandomNumber.sol";
// import "./test/UniformRandomNumber.sol";

import "@pooltogether/fixed-point/contracts/FixedPoint.sol";

///@title TsunamiDrawCalculator is an ownable implmentation of an IDrawCalculator
contract TsunamiDrawCalculator is IDrawCalculator, OwnableUpgradeable {
  
  ///@notice Ticket associated with this calculator
  ITicket ticket;

  ///@notice Cost per pick
  uint256 public pickCost;

  ///@notice Draw settings struct
  struct DrawSettings {
    uint256 range; //uint8
    uint256 matchCardinality; //uint16
    uint256[] distributions; // in order: index0: grandPrize, index1: runnerUp, etc. 
  }
  ///@notice storage of the DrawSettings associated with this Draw Calculator. NOTE: mapping? 
  DrawSettings public drawSettings;

  ///@notice Emmitted when the pickCost is set/updated
  event PickCostSet(uint256 _pickCost);

  ///@notice Emitted when the DrawParams are set/updated
  event DrawSettingsSet(DrawSettings _drawSettings);

  ///@notice Emitted when the contract is initialized
  event Initialized(ITicket indexed _ticket, DrawSettings _drawSettings); // only emit ticket?

  ///@notice Initializer sets the initial parameters
  ///@param _ticket Ticket associated with this DrawCalculator
  ///@param _pickCost Initial cost per Pick (e.g 10 DAI per pick)
  ///@param _drawSettings Initial DrawSettings
  function initialize(ITicket _ticket, uint256 _pickCost, DrawSettings calldata _drawSettings) public initializer {
    __Ownable_init();
    ticket = _ticket;
    drawSettings = _drawSettings;
    pickCost = _pickCost;
    emit Initialized(_ticket, _drawSettings);
    emit PickCostSet(_pickCost);
    emit DrawSettingsSet(_drawSettings);
  }

  ///@notice Calulates the prize amount for a user at particular draws. Called by a Claimable Strategy.
  ///@param user User for which to calcualte prize amount
  ///@param winningRandomNumbers the winning random numbers for the Draws
  ///@param timestamps the timestamps at which the Draws occurred 
  ///@param prizes The prizes at those Draws
  ///@param data The encoded pick indices
  ///@return The amount of prize to award to the user 
  function calculate(address user, uint256[] calldata winningRandomNumbers, uint32[] calldata timestamps, uint256[] calldata prizes, bytes calldata data) 
    external override view returns (uint256){
    
    require(winningRandomNumbers.length == timestamps.length && timestamps.length == prizes.length, "invalid-calculate-input-lengths");

    uint256[][] memory pickIndices = abi.decode(data, (uint256 [][]));
    require(pickIndices.length == timestamps.length, "invalid-pick-indices-length");
    
    uint256[] memory userBalances = ticket.getBalances(user, timestamps);
    bytes32 userRandomNumber = keccak256(abi.encodePacked(user)); // hash the users address
    
    DrawSettings memory settings = drawSettings; //sload

    uint256 prize = 0;
    
    for (uint256 index = 0; index < timestamps.length; index++) {
      prize += _calculate(winningRandomNumbers[index], prizes[index], userBalances[index], userRandomNumber, pickIndices[index], settings);
    }
    return prize;
  }

  ///@notice calculates the prize amount per Draw per users pick
  ///@param winningRandomNumber The Draw's winningRandomNumber
  ///@param prize The Draw's prize amount
  ///@param balance The users's balance for that Draw
  ///@param userRandomNumber the users randomNumber for that draw
  ///@param picks The users picks for that draw
  ///@param _drawSettings Params with the associated draw
  ///@return prize (if any) per Draw claim
  function _calculate(uint256 winningRandomNumber, uint256 prize, uint256 balance, bytes32 userRandomNumber, uint256[] memory picks, DrawSettings memory _drawSettings)
    internal view returns (uint256)
  {
    uint256 totalUserPicks = balance / pickCost;
    uint256 pickPayoutPercentage = 0;

    for(uint256 index  = 0; index < picks.length; index++){ //NOTE: should this loop terminator be totalUserPicks
      uint256 randomNumberThisPick = uint256(keccak256(abi.encode(userRandomNumber, picks[index])));
      require(picks[index] <= totalUserPicks, "user does not have this many picks");
      pickPayoutPercentage += calculatePickPercentage(randomNumberThisPick, winningRandomNumber, _drawSettings);
    }
    return (pickPayoutPercentage * prize) / 1 ether;

  }

  ///@notice Calculates the percentage of the Draw's Prize awardable to that user 
  ///@param randomNumberThisPick users random number for this Pick
  ///@param winningRandomNumber The winning number for this draw
  ///@param _drawSettings The parameters associated with the draw
  ///@return percentage of the Draw's Prize awardable to that user
  function calculatePickPercentage(uint256 randomNumberThisPick, uint256 winningRandomNumber, DrawSettings memory _drawSettings)
    internal pure returns(uint256) {
    
    uint256 percentage = 0;
    uint256 numberOfMatches = 0;
    
    for(uint256 matchIndex = 0; matchIndex < _drawSettings.matchCardinality; matchIndex++){      
      if(_getValueAtIndex(randomNumberThisPick, matchIndex, _drawSettings.range) == _getValueAtIndex(winningRandomNumber, matchIndex, _drawSettings.range)){
          numberOfMatches++;
      }          
    }
    
    uint256 prizeDistributionIndex = _drawSettings.matchCardinality - numberOfMatches; // prizeDistributionIndex == 0 : top prize, ==1 : runner-up prize etc
    
    // if prizeDistibution > distribution lenght -> there is no prize at that index
    if(prizeDistributionIndex < _drawSettings.distributions.length){ // they are going to receive prize funds
      uint256 numberOfPrizesForIndex = _drawSettings.range ** prizeDistributionIndex;   /// number of prizes for Draw = range ** prizeDistrbutionIndex
      percentage = _drawSettings.distributions[prizeDistributionIndex] / numberOfPrizesForIndex; // TODO: use FixedPoint   -- direct assign vs. += ??
    }
    return percentage;
  }

  ///@notice helper function to return the 4-bit value within a word at a specified index
  ///@param word word to index
  ///@param index index to index (max 15)
  function _getValueAtIndex(uint256 word, uint256 index, uint256 _range) internal pure returns(uint256) {
    uint256 mask =  (uint256(15)) << (index * 4);
    return UniformRandomNumber.uniform(uint256((uint256(word) & mask) >> (index * 4)), _range);
  }

  ///@notice Set the DrawCalculators DrawSettings
  ///@dev Distributions must be expressed with Ether decimals (1e18)
  ///@param _drawSettings DrawSettings struct to set
  function setDrawSettings(DrawSettings calldata _drawSettings) external onlyOwner{
    uint256 sumTotalDistributions = 0;
    uint256 distributionsLength = _drawSettings.distributions.length;
    require(_drawSettings.matchCardinality >= distributionsLength, "matchCardinality-gt-distributions");
    
    for(uint256 index = 0; index < distributionsLength; index++){
      sumTotalDistributions += _drawSettings.distributions[index];
    } 
    require(sumTotalDistributions < 1 ether, "distributions-gt-100%");
    
    drawSettings = _drawSettings; //sstore
    emit DrawSettingsSet(_drawSettings);
  }

  ///@notice Set the Pick Cost for the Draw
  ///@param _pickCost The range to set. Max 15.
  function setPickCost(uint256 _pickCost) external onlyOwner {
    pickCost = _pickCost; // require > 0 ?
    emit PickCostSet(_pickCost);
  }

}