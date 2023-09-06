// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@pooltogether/v4-core/contracts/interfaces/ITicket.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@pooltogether/v4-core/contracts/libraries/TwabLib.sol";
import "hardhat/console.sol";
import "./ITournament.sol";

contract P2P is ITournament, Ownable {
    using SafeERC20 for IERC20;
    uint8 public currentPhase;
    uint256 DEFAULT_LAST_PAYABLE_PLACEMENT = 10;
    uint256 public constant PRECISION_FACTOR = 1e12; // precision factor.
    uint256 public constant TREASURY_TAX = 30; //30%
    ERC20Balance[] internal _yieldManagerFundsBefore;
    ERC20Balance[] internal _yieldManagerFundsAfter;
    uint256 public prizePool;
    mapping(uint256 => uint256) public totalStaked;
    address public treasury;
    address public lockStaking;
    bool internal _rewardsCollectedBool;
    bool internal _setPlayerPlacementBool;
    /**
     * @notice Latest recorded tournament id.
     * @dev Starts at 0 and is incremented by 1 for each new tournament. So the first tournament will have id 0, the second 1, etc.
     */
    //uint256 internal _latestTournamentId;
    TournamentInfo public tournamentInfo;
    PlayerInfo[] public tournamentPlayersInfo;
    TournamentTwabs internal _tournamentTwabs;
    mapping(address => uint256) internal twabSharesForNonTopPlayers;
    mapping(address => uint256) internal _stakedAmount;
    mapping(address => bool) internal _collectedRewards;

    struct TournamentTwabs {
        /// @notice Record of token holders TWABs for each account.
        mapping(address => mapping(uint256 => TwabLib.Account)) userTwabs;
        TwabLib.Account tournamentTwab;
    }

    struct RewardTiers {
        //Reward percentage based on placement
        uint256[] placementRewardPercentage;
        //Only top players will receive share of yield generated, the rest wil share based on TWAB
        uint256 topPlayersPayablePlacement;
    }

    RewardTiers public rewardTiers;

    /**
     * @notice Dashboard UI stats
     * @param totalParticipated total number of participants for the current tournament
     * @param stakingStartTimestamp start staking time of the tournament
     * @param stakingEndTimestamp end staking time of the tournament
     * @param tournamentStartTimestamp tournament start time
     * @param tournamentEndTimestamp tournament end time
     */
    struct DashboardStats {
        uint256 totalParticipated;
        uint256 stakingStartTimestamp;
        uint256 stakingEndTimestamp;
        uint256 tournamentStartTimestamp;
        uint256 tournamentEndTimestamp;
    }

    /**
     * @notice Emitted when a tournament is created.
     * @param _tournamentInfo tournamentInfo of the tournament
     */
    event TournamentCreated(TournamentInfo _tournamentInfo);

    /**
     * @notice Emitted when a tournament is ended.
     * @param tournamentId Id of the tournament being ended
     * @param recipient Address of the recipient that will receive the remaining rewards
     */
    event TournamentEnded(
        uint256 indexed tournamentId,
        address indexed recipient
    );

    /**
     * @notice Emitted when a tournament is destroyed.
     * @param tournamentId Id of the tournament being destroyed
     * @param recipient Address of the recipient that will receive the unclaimed rewards
     * @param amount Amount of tokens transferred to the recipient
     */
    event TournamentDestroyed(
        uint256 indexed tournamentId,
        address indexed recipient,
        uint256 amount
    );

    /**
     * @notice Emitted when a tournament is extended.
     * @param tournamentId Id of the tournament being extended
     * @param newTournamentEndTime new tournament end time
     */
    event TournamentExtended(
        uint256 indexed tournamentId,
        uint256 newTournamentEndTime
    );

    /**
     * @notice Emitted when rewards have been claimed.
     * @param tournamentId Id of the tournament for which epoch rewards were claimed
     * @param user Address of the user for which the rewards were claimed
     * @param amount Amount of tokens transferred to the recipient address
     */
    event RewardsClaimed(
        uint256 indexed tournamentId,
        address indexed user,
        uint256 amount
    );

    /**
     * @notice Emitted when rewards have been claimed.
     * @param beforePhase the tournament's phase before changing
     * @param afterPhase the tournament's phase after changing
     */
    event SetTournamentPhase(
        uint8 indexed beforePhase,
        uint8 indexed afterPhase
    );

    /**
     * @notice Emitted when a new TWAB has been recorded.
     * @param delegate The recipient of the ticket power (may be the same as the user).
     * @param tokenID The token ID to increase twab
     * @param newTwab Updated TWAB of a ticket holder after a successful TWAB recording.
     */
    event NewUserTwab(
        address indexed delegate,
        uint256 tokenID,
        ObservationLib.Observation newTwab
    );

    /**
     * @notice Emitted when a new deposit has occur
     * @param _user the address who deposited
     * @param _tokenID index for the ERC20 token
     * @param _amount deposit amount
     */
    event DepositERC20(address _user, uint256 _tokenID, uint256 _amount);

    /**
     * @notice Emitted when a new withdraw has occur
     * @param _user the address who withdraw
     * @param _amount deposit amount
     */
    event WithdrawTournament(address _user, uint256 _amount);

    /**
     * @notice Emitted when yield is collected from ApeCoinStaking
     * @param _balanceBefore balance before collecting yield
     * @param _balanceAfter balance after collected yield
     * @param _rewardsCollected total yield collected
     * @param _taxCollected tax collected and sent to treasury
     * @param _prizePool prize pool to be distribute to players
     * @param _timeStamp timestamp when the yield is collected
     */
    event collectedYield(
        uint256 _balanceBefore,
        uint256 _balanceAfter,
        uint256 _rewardsCollected,
        uint256 _taxCollected,
        uint256 _prizePool,
        uint256 _timeStamp
    );

    /**
     * @notice Emitted when a user has collected rewards
     * @param _user the address who collect rewards
     * @param _userRewards amount of rewards collected
     */
    event UserCollectedRewards(address _user, uint256 _userRewards);

    /**
     * @notice Emitted when a new trewasury address has been set
     * @param _oldTreasury address of the old treasury
     * @param _newTreasury address of the new treasury
     */
    event SetTreasury(address _oldTreasury, address _newTreasury);

    /**
     * @notice Emitted when a new placement reward percentage was set
     * @param _rewardsPercentage new placement reward percerntage set
     */
    event SetPlacementRewardPercentage(uint256[] _rewardsPercentage);

    /**
     * @notice Emitted when tournament manager role was transferred
     * @param _oldTournamentManager address of previous tournament manager
     * @param _newTournamentManager address of new tournament manager
     * @param _transferTimestamp timestamp of transfer tournament manager
     */
    event TransferTournamentManager(
        address _oldTournamentManager,
        address _newTournamentManager,
        uint256 _transferTimestamp
    );

    /**
     * @notice Emitted when yield manager role was transferred
     * @param _oldYieldManager address of previous yield manager
     * @param _newYieldManager address of new yield manager
     * @param _transferTimestamp timestamp of transfer yield manager
     */
    event TransferYieldManager(
        address _oldYieldManager,
        address _newYieldManager,
        uint256 _transferTimestamp
    );

    /**
     * @notice Emitted when player's placement was set
     * @param _player array of player to set placement
     * @param _placement placement set for the corresponding player array
     */
    event SetPlayerPlacement(address[] _player, uint256[] _placement);

    /**
     * @notice Emmited with new stake token was added
     * @param _tokenAddress erc20 token's address that was added
     */
    event AddStakeToken(address _tokenAddress);

    /**
     * @notice Emitted after token has been transfer from this contract to yield manager's wallet
     * @param _tokenID token's ID to be transfered
     * @param _amount token amount to be transfered
     */
    event TransferFundsToYieldManager(uint256 _tokenID, uint256 _amount);

    /**
     * @notice Emitted after token has been transfer from this contract to yield manager's wallet
     * @param _tokenID token's ID
     * @param _fundsBeforeTransfer funds balance before transfer
     * @param _fundsAfterTransfer funds after before transfer
     */
    event UpdateYieldManagerBalanceBefore(
        uint256 _tokenID,
        uint256 _fundsBeforeTransfer,
        uint256 _fundsAfterTransfer
    );

    /**
     *@notice Emitted after caling updateYieldManagerBalanceAfter function
     * @param _fundsBeforeCallingFunction balances of erc20 tokens before calling updateYieldManagerBalanceAfter function
     * @param _fundsAfterCallingFunction balances of erc20 tokens after calling updateYieldManagerBalanceAfter function
     */
    event UpdateYieldManagerBalanceAfter(
        ERC20Balance[] _fundsBeforeCallingFunction,
        ERC20Balance[] _fundsAfterCallingFunction
    );

    /* ============ Constructor ============ */
    /**
     * @notice Constructor of the contract.
     * @param _stakeToken token used for staking
     * @param _startTimeStamp start timestamp of the tournament
     * @param _endTimeStamp end timestamp of the tournament
     * @param _minStake minimum stake amount
     * @param _tournamentManager tournament manager
     * @param _yieldManager yield manager
     * @param _treasury address of treasury
     */
    constructor(
        address _stakeToken,
        uint256 _startTimeStamp,
        uint256 _endTimeStamp,
        uint256 _minStake,
        address _tournamentManager,
        address _yieldManager,
        address _treasury
    ) {
        address[] memory stakeToken = new address[](1);
        stakeToken[0] = _stakeToken;
        tournamentInfo = TournamentInfo({
            stakeToken: stakeToken,
            tournamentManager: _tournamentManager,
            yieldManager: _yieldManager,
            startTimeStamp: _startTimeStamp,
            endTimeStamp: _endTimeStamp,
            createdAt: block.timestamp,
            minStakeAmount: _minStake
        });

        _yieldManagerFundsBefore.push(
            ERC20Balance({tokenAddress: address(_stakeToken), tokenBalance: 0})
        );

        _yieldManagerFundsAfter.push(
            ERC20Balance({tokenAddress: address(_stakeToken), tokenBalance: 0})
        );

        treasury = _treasury;

        //Default Rewards Model
        RewardTiers storage tempRewards = rewardTiers;

        //Top players will receive rewards based on their placement
        //Remaining will be receive rewards divided among each other based on twab
        tempRewards.placementRewardPercentage.push(0);
        tempRewards.placementRewardPercentage.push(30);
        tempRewards.placementRewardPercentage.push(20);
        tempRewards.placementRewardPercentage.push(10);

        //Only top players will be rewarded based on share if yield generated
        tempRewards.topPlayersPayablePlacement =
            tempRewards.placementRewardPercentage.length -
            1;

        emit TournamentCreated(tournamentInfo);
    }

    /* ============ Only Creator Functions ============ */
    /**
     * @notice get the pending rewards of this tournament from ApeCoinStaking
     */
    // function getPendingRewards() external view returns (uint256) {
    //     _requireTournamentManager();

    //     return apeCoinStaking.pendingRewards(0, address(this), 0);
    // }

    /**
     * @notice set tournament current phase
     * @param index the indexed phase to set the tournament
     * --------------------------------
     * Index        Phase
     * 0            PREPARATION
     * 1            ONGOING
     * 2            REWARD_COLLECTION
     * 3            ENDED
     * --------------------------------
     */
    function setTournamentPhase(uint256 index) public {
        _requireTournamentManager();
        uint8 beforePhase = currentPhase;
        if (index == 0) {
            currentPhase = uint8(Phases.PREPARATION);
        } else if (index == 1) {
            require(
                block.timestamp >= tournamentInfo.startTimeStamp,
                "Can only start tournament after tournament's start timestamp"
            );
            require(
                block.timestamp < tournamentInfo.endTimeStamp,
                "Can only start tournament before tournament's end timestamp"
            );
            currentPhase = uint8(Phases.ONGOING);
        } else if (index == 2) {
            require(
                block.timestamp >= tournamentInfo.endTimeStamp,
                "Can only end tournament after tournament's end timestamp"
            );
            currentPhase = uint8(Phases.REWARD_COLLECTION);
        } else if (index == 3) {
            currentPhase = uint8(Phases.ENDED);
        }

        emit SetTournamentPhase(beforePhase, currentPhase);
    }

    /**
     * @notice set rewards(percentage) for the respective placement
     * example: [50, 25, 15, 5]
     * Placement    Rewards in percentage
     * 1            50
     * 2            25
     * 3            15
     * 4            5
     */
    function setPlacementRewardPercentage(
        uint256[] calldata _rewardsPercentage
    ) external {
        _requireTournamentManager();

        delete rewardTiers;

        rewardTiers.placementRewardPercentage.push(0);

        for (uint256 i = 0; i < _rewardsPercentage.length; i++) {
            rewardTiers.placementRewardPercentage.push(_rewardsPercentage[i]);
        }

        //Only top X players will be rewarded based on share if yield generated
        //where X is the length of the _rewardsPercentage array
        rewardTiers.topPlayersPayablePlacement =
            rewardTiers.placementRewardPercentage.length -
            1;

        emit SetPlacementRewardPercentage(_rewardsPercentage);
    }

    /**
     * @notice set new treasury address
     * @param _treasury new treasury address
     */
    function setTreasury(address _treasury) external {
        _requireTournamentManager();

        address oldTreasury = treasury;

        treasury = _treasury;

        emit SetTreasury(oldTreasury, treasury);
    }

    /**
     * @notice set lockStaking address
     * @param _lockStaking address of lockStaking
     */
    function setLockStaking(address _lockStaking) external {
        _requireTournamentManager();
        lockStaking = _lockStaking;
    }

    function addStakeToken(address _tokenAddress) external {
        _requireTournamentManager();

        // tournamentInfo.stakeToken.push(
        //     ERC20Balance({tokenAddress: _tokenAddress, tokenBalance: 0})
        // );

        tournamentInfo.stakeToken.push(_tokenAddress);

        _yieldManagerFundsBefore.push(
            ERC20Balance({tokenAddress: _tokenAddress, tokenBalance: 0})
        );

        _yieldManagerFundsAfter.push(
            ERC20Balance({tokenAddress: _tokenAddress, tokenBalance: 0})
        );

        require(
            (tournamentInfo.stakeToken.length ==
                _yieldManagerFundsBefore.length) &&
                (_yieldManagerFundsBefore.length ==
                    _yieldManagerFundsAfter.length),
            "stake tokens records are not the same"
        );
    }

    function transferFundsToYieldManager(
        uint256 _tokenID,
        uint256 _amount
    ) external {
        _requireYieldManager();

        IERC20(tournamentInfo.stakeToken[_tokenID]).transferFrom(
            address(this),
            tournamentInfo.yieldManager,
            _amount
        );

        uint256 balanceBefore = _yieldManagerFundsBefore[_tokenID].tokenBalance;
        _yieldManagerFundsBefore[_tokenID].tokenBalance += _amount;

        emit UpdateYieldManagerBalanceBefore(
            _tokenID,
            balanceBefore,
            _yieldManagerFundsBefore[_tokenID].tokenBalance
        );
        emit TransferFundsToYieldManager(_tokenID, _amount);
    }

    /**
     * @notice update yield manager's funds after collecting yield from yield source
     * @dev *IMPORTANT* only call this function AFTER yield was collected from yield source!
     */
    function updateYieldManagerBalanceAfter() external {
        _requireYieldManager();
        ERC20Balance[] memory yieldManagerFundsAfter = _yieldManagerFundsAfter;
        for (uint i = 0; i < tournamentInfo.stakeToken.length; i++) {
            _yieldManagerFundsAfter[i].tokenBalance += IERC20(
                tournamentInfo.stakeToken[i]
            ).balanceOf(tournamentInfo.yieldManager);
        }

        emit UpdateYieldManagerBalanceAfter(
            yieldManagerFundsAfter,
            _yieldManagerFundsAfter
        );
    }

    /**
     * @notice transfer tournament manager role to new address
     * @param _newTournamentManager address of new tournament manager
     */
    function transferTournamentManager(address _newTournamentManager) external {
        _requireTournamentManager();
        address oldTournamentManager = tournamentInfo.tournamentManager;
        tournamentInfo.tournamentManager = _newTournamentManager;

        emit TransferTournamentManager(
            oldTournamentManager,
            _newTournamentManager,
            block.timestamp
        );
    }

    /**
     * @notice transfer yield manager role to new address
     * @param _newYieldManager address of new yield manager
     */
    function transferYieldManager(address _newYieldManager) external {
        _requireYieldManager();
        address oldYieldManager = tournamentInfo.yieldManager;
        tournamentInfo.yieldManager = _newYieldManager;

        emit TransferYieldManager(
            oldYieldManager,
            _newYieldManager,
            block.timestamp
        );
    }

    /**
     * @notice reset tournament state
     * @dev use when tournament has ended and tournament manager want to start a new tournament
     * @dev tournament phase will be set to PREPARATION phase
     * @dev all player's placement and prizepool will be reset
     */
    function resetTournamentState() internal {
        _requireTournamentManager();

        //Reset twabs for non top players
        for (uint256 i = 0; i < tournamentPlayersInfo.length; i++) {
            twabSharesForNonTopPlayers[tournamentPlayersInfo[i].player] = 0;
        }

        //Reset all player's placement
        for (uint256 i = 0; i < tournamentPlayersInfo.length; i++) {
            tournamentPlayersInfo[i].placement = 0;
        }

        //Reset yield manager funds
        require(
            _yieldManagerFundsBefore.length == _yieldManagerFundsAfter.length,
            "yield manager funds before and after recorded tokens are not the same"
        );
        for (uint256 i = 0; i < _yieldManagerFundsBefore.length; i++) {
            _yieldManagerFundsBefore[i].tokenBalance = 0;
            _yieldManagerFundsAfter[i].tokenBalance = 0;
        }

        _setPlayerPlacementBool = false;

        setTournamentPhase(0);

        _rewardsCollectedBool = false;

        prizePool = 0;

        delete tournamentInfo;
    }

    /**
     * @notice set player's placement
     * @param _player player's address array
     * @param _placement player's placement array
     * @dev player's address array and _placement array must be the same length
     * */
    function setPlayerPlacement(
        address[] calldata _player,
        uint256[] calldata _placement
    ) external {
        bool exist;
        uint256 index;

        _requireTournamentManager();

        require(
            _player.length == _placement.length,
            "Number of addresses must be the same as number of placement"
        );

        for (uint256 i = 0; i < _player.length; i++) {
            (exist, index) = getUserIndex(_player[i]);
            require(exist, "Player does not exist");
            tournamentPlayersInfo[index].placement = _placement[i];
        }

        _setPlayerPlacementBool = true;

        //emit event, not sure whats the best event to emit, need to see backend need what info
        emit SetPlayerPlacement(_player, _placement);
    }

    /* ============ External Functions ============ */
    /**
     * @notice call by player to deposit APE coin to participate in the tournament
     * @param _amount amount to deposit
     */
    function depositERC20(uint256 _tokenID, uint256 _amount) external override {
        bool exist;
        uint256 index;

        require(_amount > 0, "Nothing to deposit");

        IERC20(tournamentInfo.stakeToken[_tokenID]).transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        IERC20(tournamentInfo.stakeToken[_tokenID]).approve(
            address(this),
            _amount
        );
        IERC20(tournamentInfo.stakeToken[_tokenID]).transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        (exist, index) = getUserIndex(msg.sender);
        if (!exist) {
            PlayerInfo storage playerInfo = tournamentPlayersInfo.push();
            playerInfo.player = msg.sender;
            playerInfo.placement = 0;
            playerInfo.stakedAmount[_tokenID] = _amount;
            playerInfo.lockedAmount[_tokenID] = 0;
            playerInfo.rewardsDebt = 0;
            playerInfo.collectedRewards = false;
        } else {
            //user deposit this token before
            tournamentPlayersInfo[index].stakedAmount[_tokenID] += _amount;
            // if (tournamentPlayersInfo[index].stakedAmount[_tokenID] != 0) {

            // } else {
            //     tournamentPlayersInfo[index].stakedAmount.push(
            //         ERC20Balance({
            //             tokenAddress: address(
            //                 tournamentInfo.stakeToken[_tokenID]
            //             ),
            //             tokenBalance: _amount
            //         })
            //     );
            // }
        }

        totalStaked[_tokenID] += _amount;
        _increaseUserTwab(msg.sender, _tokenID, _amount);

        emit DepositERC20(msg.sender, _tokenID, _amount);
    }

    /**
     * @notice only can be called by lockStaking contract to deposit player's locked staked into tournament
     * @param _amount amount to deposit
     */
    function lockDeposit(uint256 _tokenID, uint256 _amount) external override {
        bool exist;
        uint256 index;

        _requireLockStaking();
        require(_amount > 0, "Nothing to deposit");

        IERC20(tournamentInfo.stakeToken[_tokenID]).transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        IERC20(tournamentInfo.stakeToken[_tokenID]).approve(
            address(this),
            _amount
        );
        //apeCoinStaking.depositSelfApeCoin(_amount);

        (exist, index) = getUserIndex(tx.origin);
        if (!exist) {
            PlayerInfo storage playerInfo = tournamentPlayersInfo.push();
            playerInfo.player = msg.sender;
            playerInfo.placement = 0;
            playerInfo.stakedAmount[_tokenID] = 0;
            playerInfo.lockedAmount[_tokenID] = _amount;
            playerInfo.rewardsDebt = 0;
            playerInfo.collectedRewards = false;
        } else {
            tournamentPlayersInfo[index].lockedAmount[_tokenID] += _amount;
        }

        totalStaked[_tokenID] += _amount;
        _increaseUserTwab(tx.origin, _tokenID, _amount);

        emit DepositERC20(tx.origin, _tokenID, _amount);
    }

    /**
     * @notice call by player to withdraw deposited APE coin to withdraw from tournament
     * @param _amount amount to withdraw
     * @dev can only withdraw during REWARD_COLLECTION phase
     */
    function withdraw(uint256 _tokenID, uint256 _amount) external override {
        bool exist;
        uint256 index;

        (exist, index) = getUserIndex(msg.sender);
        require(exist, "Player does not exist");
        require(
            tournamentPlayersInfo[index].stakedAmount[_tokenID] > 0,
            "Nothing to withdraw"
        );

        require(
            tournamentPlayersInfo[index].stakedAmount[_tokenID] >= _amount,
            "Cannot withdraw more than available balance"
        );

        require(
            _isPhase(Phases.REWARD_COLLECTION),
            "Only can withdraw during REWARD_COLLECTION Phase"
        );

        tournamentPlayersInfo[index].stakedAmount[_tokenID] -= _amount;

        totalStaked[_tokenID] -= _amount;

        IERC20(tournamentInfo.stakeToken[_tokenID]).transfer(
            msg.sender,
            _amount
        );

        _decreaseUserTwab(msg.sender, _tokenID, _amount);

        emit WithdrawTournament(msg.sender, _amount);
    }

    /**
     * @notice only can be called by lockStaking contract to withdraw player's locked staked from tournament
     * @param _amount amount to withdraw
     * * @dev can only withdraw during REWARD_COLLECTION phase
     */
    function withdrawLocked(
        uint256 _tokenID,
        uint256 _amount
    ) external override {
        bool exist;
        uint256 index;
        _requireLockStaking();
        (exist, index) = getUserIndex(tx.origin);
        require(exist, "Player does not exist");
        require(
            tournamentPlayersInfo[index].lockedAmount[_tokenID] > 0,
            "Nothing to withdraw"
        );

        require(
            tournamentPlayersInfo[index].lockedAmount[_tokenID] >= _amount,
            "Cannot withdraw more than available balance"
        );

        require(
            _isPhase(Phases.REWARD_COLLECTION),
            "Only can withdraw during REWARD_COLLECTION Phase"
        );

        //apeCoinStaking.withdrawSelfApeCoin(_amount);

        tournamentPlayersInfo[index].lockedAmount[_tokenID] -= _amount;

        totalStaked[_tokenID] -= _amount;

        IERC20(tournamentInfo.stakeToken[_tokenID]).transfer(
            tx.origin,
            _amount
        );

        _decreaseUserTwab(tx.origin, _tokenID, _amount);

        emit WithdrawTournament(tx.origin, _amount);
    }

    /**
     * @notice extend tournament duration
     * @param _newTournamentEndTime new tournament end time
     * * @dev requires tournament to be active
     */
    function extendTournament(
        uint8 _newTournamentEndTime
    ) external override returns (bool) {
        _requireTournamentActive();

        require(
            _newTournamentEndTime > tournamentInfo.endTimeStamp,
            "new tournament end time need to be later than current tournament end time"
        );

        tournamentInfo.endTimeStamp = _newTournamentEndTime;

        return true;
    }

    /**
     * @notice get stats for UI dashboard
     */
    function getDashboardStats() external view returns (DashboardStats memory) {
        uint256 totalParticipated;
        for (uint256 i = 0; i < tournamentPlayersInfo.length; i++) {
            for (uint256 j = 0; j < tournamentInfo.stakeToken.length - 1; j++) {
                if (tournamentPlayersInfo[i].stakedAmount[j] > 0) {
                    totalParticipated += 1;
                    break;
                }
            }
        }
        return
            DashboardStats({
                totalParticipated: totalParticipated,
                stakingStartTimestamp: tournamentInfo.createdAt,
                stakingEndTimestamp: tournamentInfo.startTimeStamp,
                tournamentStartTimestamp: tournamentInfo.startTimeStamp,
                tournamentEndTimestamp: tournamentInfo.endTimeStamp
            });
    }

    /**
     * @notice get the rewards(percentage) corresponding to the placement
     */
    function getPlacementRewardPercentage()
        external
        view
        returns (uint256[] memory)
    {
        return rewardTiers.placementRewardPercentage;
    }

    /**
     * @notice Get settings for a specific tournament.
     * @dev Will revert if the tournament does not exist.
     * @return Tournament settings
     */
    function getTournamentInfo()
        external
        view
        override
        returns (TournamentInfo memory)
    {
        return tournamentInfo;
    }

    /**
     * @notice Retrieve tournament information of a player by address.
     * @param _user The address of the player.
     * @return player Player's address.
     * @return placement Player's placement in the tournament.
     * @return rewardsDebt Amount of rewards debt for the player.
     * @return collectedRewards Boolean indicating if the player has collected rewards.
     * @dev Look up and return various attributes of a player in the tournament.
     */
    function getTournamentPlayersInfoByAddress(
        address _user
    )
        external
        view
        returns (
            address player,
            uint256 placement,
            uint256 rewardsDebt,
            bool collectedRewards
        )
    {
        (bool exist, uint256 index) = getUserIndex(_user);
        require(exist, "Player does not exist");

        PlayerInfo storage pInfo = tournamentPlayersInfo[index];

        return (
            pInfo.player,
            pInfo.placement,
            pInfo.rewardsDebt,
            pInfo.collectedRewards
        );
    }

    /**
     * @notice Retrieve the staked amount for a player by address and token ID.
     * @param _user The address of the player.
     * @param _tokenID The ID of the token.
     * @return The staked amount for the given player and token ID.
     * @dev Fetches the staked amount from the PlayerInfo struct.
     */
    function getStakedAmountByAddressAndTokenID(
        address _user,
        uint256 _tokenID
    ) external view returns (uint256) {
        (bool exist, uint256 index) = getUserIndex(_user);
        require(exist, "Player does not exist");

        return tournamentPlayersInfo[index].stakedAmount[_tokenID];
    }

    /**
     * @notice Retrieve the locked amount for a player by address and token ID.
     * @param _user The address of the player.
     * @param _tokenID The ID of the token.
     * @return The locked amount for the given player and token ID.
     * @dev Fetches the locked amount from the PlayerInfo struct.
     */
    function getLockedAmountByAddressAndTokenID(
        address _user,
        uint256 _tokenID
    ) external view returns (uint256) {
        (bool exist, uint256 index) = getUserIndex(_user);
        require(exist, "Player does not exist");

        return tournamentPlayersInfo[index].lockedAmount[_tokenID];
    }

    /**
     * @notice Create new tournament
     * @param _startTimeStamp start timestamp for the new tournament
     * @param _endTimeStamp end timestamp for the new tournament
     * @param _minStake minimum stake amount to join the new tournament
     */
    function newTournament(
        uint256 _startTimeStamp,
        uint256 _endTimeStamp,
        uint256 _minStake
    ) external {
        tournamentInfo.startTimeStamp = _startTimeStamp;
        tournamentInfo.endTimeStamp = _endTimeStamp;
        tournamentInfo.minStakeAmount = _minStake;
        tournamentInfo.createdAt = block.timestamp;
        resetTournamentState();

        //Bring forward user's stake and reward
        //Need to make sure user's stake did not get reset
    }

    // /**
    //  * @notice claim rewards for caller
    //  * @dev can only be called during REWARD_COLLECTION phase
    //  */
    // function claimSelfRewards() external {
    //     bool exist;
    //     uint256 userRewards;
    //     uint256 userIndex;

    //     require(
    //         _isPhase(Phases.REWARD_COLLECTION),
    //         "Only can deposit during REWARD_COLLECTION Phase"
    //     );

    //     (exist, userIndex) = getUserIndex(msg.sender);
    //     require(exist, "Player does not exist");
    //     userRewards = tournamentPlayersInfo[userIndex].rewardsDebt;
    //     require(userRewards > 0, "No rewards to claim");

    //     tournamentInfo.rewardToken.transfer(msg.sender, userRewards);

    //     tournamentPlayersInfo[userIndex].rewardsDebt = 0;

    //     emit UserCollectedRewards(msg.sender, userRewards);
    // }

    /* ============ Public Functions ============ */
    function getTwabSharesForNonTopPlayers(
        uint256 _tokenID
    ) public returns (PlayerTwabInfo[] memory) {
        _requireTournamentManager();

        require(
            _setPlayerPlacementBool == true,
            "Need to set player's placement before get player's twab info"
        );

        _calculateTwabSharesForNonTopPlayers(_tokenID);

        PlayerTwabInfo[] memory playerTwabInfo = new PlayerTwabInfo[](
            tournamentPlayersInfo.length
        );

        for (uint256 i = 0; i < tournamentPlayersInfo.length; i++) {
            playerTwabInfo[i].player = tournamentPlayersInfo[i].player;
            playerTwabInfo[i].share = twabSharesForNonTopPlayers[
                tournamentPlayersInfo[i].player
            ];
        }

        return playerTwabInfo;
    }

    /**
     * @notice Retrieves the average balance of user's staked tokens from tournament start time to end time
     * @param _user The address of the user.
     * @param _startTime The start time of the time frame.
     * @param _endTime The end time of the time frame.
     */
    function getAverageBalanceBetween(
        address _user,
        uint256 _tokenID,
        uint64 _startTime,
        uint64 _endTime
    ) public view returns (uint256) {
        TwabLib.Account storage account = _tournamentTwabs.userTwabs[_user][
            _tokenID
        ];

        return
            TwabLib.getAverageBalanceBetween(
                account.twabs,
                account.details,
                uint32(_startTime),
                uint32(_endTime),
                uint32(block.timestamp)
            );
    }

    /**
     * @notice Retrieve player's placement by address
     * @param _user address of user to check placement
     */
    function getPlacementByAddress(
        address _user
    ) public view override returns (uint256) {
        (bool exist, uint256 index) = getUserIndex(_user);
        require(exist, "Player does not exist");
        return tournamentPlayersInfo[index].placement;
    }

    /* ============ Internal Functions ============ */
    /**
     * @notice check if current phase is equal to _phase
     * @param _phase phase to check
     */
    function _isPhase(Phases _phase) internal view returns (bool) {
        if (uint8(_phase) != currentPhase) {
            return false;
        } else {
            return true;
        }
    }

    function _requireTournamentActive() internal view {
        require(
            tournamentInfo.endTimeStamp > block.timestamp,
            "tournament inactive"
        );
    }

    function _requireYieldManager() internal view {
        require(
            msg.sender == tournamentInfo.yieldManager,
            "can only be called by tournament manager"
        );
    }

    function _requireTournamentManager() internal view {
        require(
            msg.sender == tournamentInfo.tournamentManager,
            "can only be called by tournament manager"
        );
    }

    function _requireLockStaking() internal view {
        require(
            msg.sender == lockStaking,
            "can only be called by lockStaking contract"
        );
    }

    /**
     *
     * @param _user user's address to get index
     * @return exist true if player exist and vice versa
     * @return index index of player if exist, returns 0 if does not
     */
    function getUserIndex(
        address _user
    ) internal view returns (bool exist, uint256 index) {
        for (uint256 i = 0; i < tournamentPlayersInfo.length; i++) {
            if (tournamentPlayersInfo[i].player == _user) {
                exist = true;
                index = i;
                return (exist, index);
            }
        }

        exist = false;
        return (exist, 0);
    }

    /**
     * @notice Retrieves tournament end timestamp.
     * @return Tournament end timestamp
     */
    function _getTournamentEndTimestamp() internal view returns (uint256) {
        return tournamentInfo.endTimeStamp;
    }

    /**
     * @notice Retrieves the average balances held by a user for a given time frame.
     * @param _account The user whose balance is checked.
     * @param _startTimes The start time of the time frame.
     * @param _endTimes The end time of the time frame.
     * @return The average balance that the user held during the time frame.
     */
    function _getAverageBalancesBetween(
        TwabLib.Account storage _account,
        uint64[] calldata _startTimes,
        uint64[] calldata _endTimes
    ) internal view returns (uint256[] memory) {
        uint256 startTimesLength = _startTimes.length;
        require(
            startTimesLength == _endTimes.length,
            "Ticket/start-end-times-length-match"
        );

        TwabLib.AccountDetails memory accountDetails = _account.details;

        uint256[] memory averageBalances = new uint256[](startTimesLength);
        uint32 currentTimestamp = uint32(block.timestamp);

        for (uint256 i = 0; i < startTimesLength; i++) {
            averageBalances[i] = TwabLib.getAverageBalanceBetween(
                _account.twabs,
                accountDetails,
                uint32(_startTimes[i]),
                uint32(_endTimes[i]),
                currentTimestamp
            );
        }

        return averageBalances;
    }

    /**
     * @notice calculate Twab shares for non top players
     */
    function _calculateTwabSharesForNonTopPlayers(uint256 _tokenID) internal {
        uint256 totalTwabFromNonTopPlayers;

        for (uint256 i = 0; i < tournamentPlayersInfo.length; i++) {
            if (
                getPlacementByAddress(tournamentPlayersInfo[i].player) >
                rewardTiers.topPlayersPayablePlacement
            ) {
                totalTwabFromNonTopPlayers += getAverageBalanceBetween(
                    tournamentPlayersInfo[i].player,
                    _tokenID,
                    uint64(tournamentInfo.createdAt),
                    uint64(block.timestamp)
                );
            }
        }

        for (uint256 i = 0; i < tournamentPlayersInfo.length; i++) {
            if (
                getPlacementByAddress(tournamentPlayersInfo[i].player) >
                rewardTiers.topPlayersPayablePlacement
            ) {
                twabSharesForNonTopPlayers[tournamentPlayersInfo[i].player] =
                    (getAverageBalanceBetween(
                        tournamentPlayersInfo[i].player,
                        _tokenID,
                        uint64(tournamentInfo.createdAt),
                        uint64(block.timestamp)
                    ) * PRECISION_FACTOR) /
                    totalTwabFromNonTopPlayers;
            }
        }
    }

    /**
     * @notice Increase `_to` TWAB balance.
     * @param _to Address of the delegate.
     * @param _amount Amount of tokens to be added to `_to` TWAB balance.
     */
    function _increaseUserTwab(
        address _to,
        uint256 _tokenID,
        uint256 _amount
    ) internal {
        if (_amount == 0) {
            return;
        }

        TwabLib.Account storage _account = _tournamentTwabs.userTwabs[_to][
            _tokenID
        ];

        (
            TwabLib.AccountDetails memory accountDetails,
            ObservationLib.Observation memory twab,
            bool isNew
        ) = TwabLib.increaseBalance(
                _account,
                uint208(_amount),
                uint32(block.timestamp)
            );

        _account.details = accountDetails;

        if (isNew) {
            emit NewUserTwab(_to, _tokenID, twab);
        }
    }

    /**
     * @notice Decrease `_to` TWAB balance.
     * @param _to Address of the delegate.
     * @param _amount Amount of tokens to be added to `_to` TWAB balance.
     */
    function _decreaseUserTwab(
        address _to,
        uint256 _tokenID,
        uint256 _amount
    ) internal {
        if (_amount == 0) {
            return;
        }

        TwabLib.Account storage _account = _tournamentTwabs.userTwabs[_to][
            _tokenID
        ];

        (
            TwabLib.AccountDetails memory accountDetails,
            ObservationLib.Observation memory twab,
            bool isNew
        ) = TwabLib.decreaseBalance(
                _account,
                uint208(_amount),
                "PoolToPlay/insufficient-balance",
                uint32(block.timestamp)
            );

        _account.details = accountDetails;

        if (isNew) {
            emit NewUserTwab(_to, _tokenID, twab);
        }
    }
}
