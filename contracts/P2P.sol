// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@pooltogether/v4-core/contracts/libraries/TwabLib.sol";
import "hardhat/console.sol";
import "./ITournament.sol";

contract P2P is ITournament, Ownable {
    using SafeERC20 for IERC20;
    uint8 public currentPhase;
    uint256 public constant PRECISION_FACTOR = 1e12; // precision factor.
    uint256 public constant ETH_TOKEN_ID = 0;
    ERC20Balance[] internal _yieldManagerFundsBefore;
    ERC20Balance[] internal _yieldManagerFundsAfter;
    mapping(uint256 => uint256) public totalStaked;
    address public lockStaking;
    /**
     * @notice Latest recorded tournament id.
     * @dev Starts at 0 and is incremented by 1 for each new tournament. So the first tournament will have id 0, the second 1, etc.
     */
    //uint256 internal _latestTournamentId;
    TournamentInfo public tournamentInfo;
    PlayerInfo[] public tournamentPlayersInfo;
    TournamentTwabs internal _tournamentTwabs;
    mapping(address => uint256) internal _stakedAmount;

    struct TournamentTwabs {
        /// @notice Record of token holders TWABs for each account.
        mapping(address => mapping(uint256 => TwabLib.Account)) userTwabs;
        TwabLib.Account tournamentTwab;
    }

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

    // /**
    //  * @notice Emitted when rewards have been claimed.
    //  * @param tournamentId Id of the tournament for which epoch rewards were claimed
    //  * @param user Address of the user for which the rewards were claimed
    //  * @param amount Amount of tokens transferred to the recipient address
    //  */
    // event RewardsClaimed(
    //     uint256 indexed tournamentId,
    //     address indexed user,
    //     uint256 amount
    // );

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
     * @notice Emitted when a new deposit has occur
     * @param _user the address who deposited
     * @param _amount deposit amount
     */
    event DepositETH(address _user, uint256 _amount);

    /**
     * @notice Emitted when a new withdraw has occur
     * @param _user the address who withdraw
     * @param _tokenID index for the ERC20 token
     * @param _amount deposit amount
     */
    event WithdrawERC20(address _user, uint256 _tokenID, uint256 _amount);

    /**
     * @notice Emitted when a new withdraw has occur
     * @param _user the address who withdraw
     * @param _amount deposit amount
     */
    event WithdrawETH(address _user, uint256 _amount);

    /**
     * @notice Emitted when a user has collected rewards
     * @param _user the address who collect rewards
     * @param _userRewards amount of rewards collected
     */
    event UserCollectedRewards(address _user, uint256 _userRewards);

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
     */
    constructor(
        address _stakeToken,
        uint256 _startTimeStamp,
        uint256 _endTimeStamp,
        uint256 _minStake,
        address _tournamentManager,
        address _yieldManager
    ) {
        address[] memory stakeToken = new address[](2);
        stakeToken[0] = 0x0000000000000000000000000000000000000000; //reserved for ETH
        stakeToken[1] = _stakeToken; //reserved for first ERC20 token
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

        if (_tokenID == 0) {
            payable(tournamentInfo.yieldManager).transfer(_amount);
        } else {
            IERC20(tournamentInfo.stakeToken[_tokenID]).transferFrom(
                address(this),
                tournamentInfo.yieldManager,
                _amount
            );
        }

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
     */
    function resetTournamentState() internal {
        _requireTournamentManager();

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

        setTournamentPhase(0);

        //delete tournamentInfo;
    }

    /* ============ External Functions ============ */
    /**
     * @notice call by player to deposit ERC20 token to participate in the tournament
     * @param _amount amount to deposit
     */
    function depositERC20(uint256 _tokenID, uint256 _amount) external override {
        bool exist;
        uint256 index;

        require(_tokenID != 0, "cannot deposit ETH using this function");

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
        }

        totalStaked[_tokenID] += _amount;
        _increaseUserTwab(msg.sender, _tokenID, _amount);

        emit DepositERC20(msg.sender, _tokenID, _amount);
    }

    /**
     * @notice call by player to deposit ETH to participate in the tournament
     */
    function depositETH() external payable override {
        bool exist;
        uint256 index;

        require(msg.value > 0, "Nothing to deposit");

        require((msg.sender).balance > msg.value, "insufficient balance");

        (exist, index) = getUserIndex(msg.sender);
        if (!exist) {
            PlayerInfo storage playerInfo = tournamentPlayersInfo.push();
            playerInfo.player = msg.sender;
            playerInfo.placement = 0;
            playerInfo.stakedAmount[ETH_TOKEN_ID] = msg.value;
            playerInfo.lockedAmount[ETH_TOKEN_ID] = 0;
            playerInfo.rewardsDebt = 0;
            playerInfo.collectedRewards = false;
        } else {
            //user deposit this token before
            tournamentPlayersInfo[index].stakedAmount[ETH_TOKEN_ID] += msg
                .value;
        }

        totalStaked[ETH_TOKEN_ID] += msg.value;
        _increaseUserTwab(msg.sender, ETH_TOKEN_ID, msg.value);

        emit DepositERC20(msg.sender, ETH_TOKEN_ID, msg.value);
    }

    /**
     * @notice only can be called by lockStaking contract to deposit player's locked staked into tournament
     * @param _amount amount to deposit
     */
    function lockDeposit(uint256 _tokenID, uint256 _amount) external override {
        bool exist;
        uint256 index;

        _requireLockStaking();

        require(_tokenID != 0, "cannot lock deposit ETH");

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
    function withdrawERC20(
        uint256 _tokenID,
        uint256 _amount
    ) external override {
        bool exist;
        uint256 index;

        require(_tokenID != 0, "cannot withdraw ETH using this function");

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

        emit WithdrawERC20(msg.sender, _tokenID, _amount);
    }

    /**
     * @notice call by player to withdraw deposited APE coin to withdraw from tournament
     * @param _amount amount to withdraw
     * @dev can only withdraw during REWARD_COLLECTION phase
     */
    function withdrawETH(uint256 _amount) external payable override {
        bool exist;
        uint256 index;
        address payable user = payable(msg.sender);

        (exist, index) = getUserIndex(msg.sender);
        require(exist, "Player does not exist");
        require(
            tournamentPlayersInfo[index].stakedAmount[ETH_TOKEN_ID] > 0,
            "Nothing to withdraw"
        );

        require(
            tournamentPlayersInfo[index].stakedAmount[ETH_TOKEN_ID] >= _amount,
            "Cannot withdraw more than available balance"
        );

        require(
            _isPhase(Phases.REWARD_COLLECTION),
            "Only can withdraw during REWARD_COLLECTION Phase"
        );

        tournamentPlayersInfo[index].stakedAmount[ETH_TOKEN_ID] -= _amount;

        totalStaked[ETH_TOKEN_ID] -= _amount;

        user.transfer(_amount);

        _decreaseUserTwab(msg.sender, ETH_TOKEN_ID, _amount);

        emit WithdrawETH(msg.sender, _amount);
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
        require(_tokenID != 0, "cannot lock deposit ETH");

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

        emit WithdrawERC20(tx.origin, _tokenID, _amount);
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
