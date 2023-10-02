// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@pooltogether/v4-core/contracts/interfaces/ITicket.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@pooltogether/v4-core/contracts/libraries/TwabLib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import "./ITournament.sol";

contract RewardSClaim {
    address private yieldManager;
    bool internal _updatePlayersRewardsBool;
    IERC20 public rewardToken;
    bool public canClaimRewards;

    struct PlayerInfo {
        uint256 rewardsDebt;
        bool collectedRewardsBool;
    }

    mapping(address => PlayerInfo) public tournamentPlayersInfo;

    modifier onlyYieldManager() {
        require(
            msg.sender == yieldManager,
            "can only be called by tournament manager"
        );
        _;
    }

    constructor(address yieldManager_, address rewardToken_) {
        yieldManager = yieldManager_;
        rewardToken = IERC20(rewardToken_);
    }

    /**
     * @notice set player's placement
     * @param _player player's address array
     * @param _rewardsAmount player's placement array
     * @dev player's address array and _placement array must be the same length
     * */
    function addPlayerRewards(
        address[] calldata _player,
        uint256[] calldata _rewardsAmount
    ) external onlyYieldManager {
        require(
            _player.length == _rewardsAmount.length,
            "Number of addresses must be the same as number of placement"
        );

        for (uint256 i = 0; i < _player.length; i++) {
            //if player has existing reward dept
            if (tournamentPlayersInfo[_player[i]].rewardsDebt != 0) {
                tournamentPlayersInfo[_player[i]].rewardsDebt += _rewardsAmount[
                    i
                ];
            } else {
                tournamentPlayersInfo[_player[i]].rewardsDebt = _rewardsAmount[
                    i
                ];
            }
        }

        _updatePlayersRewardsBool = true;

        //emit event, not sure whats the best event to emit, need to see backend need what info
        //emit SetPlayerPlacement(_player, _placement);
    }

    function setCanClaimRewardsBool(
        bool canClaimRewards_
    ) external onlyYieldManager {
        canClaimRewards = canClaimRewards_;
    }

    /**
     * @notice claim rewards for caller
     * @dev can only be called if canClaimRewards = true
     */
    function claimSelfRewards() external {
        uint256 userRewards;

        require(canClaimRewards, "Cannot collect rewards yet!");

        userRewards = tournamentPlayersInfo[msg.sender].rewardsDebt;
        require(userRewards > 0, "No rewards to claim");

        rewardToken.transfer(msg.sender, userRewards);

        tournamentPlayersInfo[msg.sender].rewardsDebt = 0;

        //emit UserCollectedRewards(msg.sender, userRewards);
    }
}
