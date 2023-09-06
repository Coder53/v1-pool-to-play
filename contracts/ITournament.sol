// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITournament {
    struct TournamentInfo {
        address yieldManager;
        address tournamentManager;
        uint256 startTimeStamp;
        uint256 endTimeStamp;
        uint256 createdAt;
        address[] stakeToken;
        uint256 minStakeAmount;
    }

    struct PlayerInfo {
        address player;
        uint256 placement;
        mapping(uint256 => uint256) stakedAmount;
        mapping(uint256 => uint256) lockedAmount;
        uint256 rewardsDebt;
        bool collectedRewards;
    }

    struct ERC20Balance {
        address tokenAddress;
        uint256 tokenBalance;
    }

    struct PlayerTwabInfo {
        address player;
        uint256 share;
    }

    enum Phases {
        PREPARATION,
        ONGOING,
        REWARD_COLLECTION,
        ENDED
    }

    /**
     * @notice Extend Tournament by adding more epochs.
     * @param _newTournamentEndTime new tournament end time
     * @return True if the operation was successful
     */
    function extendTournament(
        uint8 _newTournamentEndTime
    ) external returns (bool);

    function getTournamentInfo() external view returns (TournamentInfo memory);

    function getPlacementByAddress(
        address _user
    ) external view returns (uint256);

    //function collectYieldAndDistributeRewards() external;

    function depositERC20(uint256 _tokenID, uint256 _amount) external;

    function lockDeposit(uint256 _tokenID, uint256 _amount) external;

    function withdraw(uint256 _tokenID, uint256 _amount) external;

    function withdrawLocked(uint256 _tokenID, uint256 _amount) external;
}
