# PoolToPlay Contract

This contract provides functionality for managing tournaments and player participation using ERC20 tokens.

## Table of Contents

1. [Setting Tournament Phase](#1-setting-tournament-phase)
2. [Setting Placement Reward Percentage](#2-setting-placement-reward-percentage)
3. [Setting Treasury](#3-setting-treasury)
4. [Setting Lock Staking Contract](#4-setting-lock-staking-contract)
5. [Adding Stake Token](#5-adding-stake-token)
6. [Transferring Funds to Yield Manager](#6-transferring-funds-to-yield-manager)
7. [Updating Yield Manager Balance After](#7-updating-yield-manager-balance-after)
8. [Transferring Tournament Manager Role](#8-transferring-tournament-manager-role)
9. [Transferring Yield Manager Role](#9-transferring-yield-manager-role)
10. [Setting Player Placement](#10-setting-player-placement)
11. [Depositing ERC20 Tokens](#11-depositing-erc20-tokens)
12. [Locking Deposits](#12-locking-deposits)
13. [Withdrawing Deposits](#13-withdrawing-deposits)
14. [Withdrawing Locked Tokens](#14-withdrawing-locked-tokens)
15. [Extending Tournament Duration](#15-extending-tournament-duration)
16. [Getting Dashboard Stats](#16-getting-dashboard-stats)
17. [Getting Placement Reward Percentage](#17-getting-placement-reward-percentage)
18. [Getting Tournament Info](#18-getting-tournament-info)
19. [Getting Player's Tournament Info](#19-getting-players-tournament-info)
20. [Getting Staked Amount by Address and Token ID](#20-getting-staked-amount-by-address-and-token-id)
21. [Getting Locked Amount by Address and Token ID](#21-getting-locked-amount-by-address-and-token-id)
22. [Creating a New Tournament](#22-creating-a-new-tournament)
23. [Getting TWAB Shares for Non-Top Players](#23-getting-twab-shares-for-non-top-players)
24. [Getting Average Balance Between](#24-getting-average-balance-between)
25. [Getting Placement by Address](#25-getting-placement-by-address)

---

## 1. Setting Tournament Phase

### Function: `setTournamentPhase(uint256 index) external`

This function is used to set the current phase of the tournament.

**Parameters:**

- `index`: The index of the phase to set:
  - 0: PREPARATION
  - 1: ONGOING
  - 2: REWARD_COLLECTION
  - 3: ENDED

...

## 2. Setting Placement Reward Percentage

### Function: `setPlacementRewardPercentage(uint256[] calldata _percentages) external`

This function is used to set the reward percentages for each placement in the tournament.

**Parameters:**

- `_percentages`: An array of reward percentages for each placement.

...

## 3. Setting Treasury

### Function: `setTreasury(address _treasury) external`

This function is used to set the treasury address for the tournament.

**Parameters:**

- `_treasury`: The address of the treasury.

...

## 4. Setting Lock Staking Contract

### Function: `setLockStaking(address _lockStaking) external`

This function is used to set the address of the lock staking contract.

**Parameters:**

- `_lockStaking`: The address of the lock staking contract.

...

## 5. Adding Stake Token

### Function: `addStakeToken(address _token) external`

This function is used to add a new stake token for the tournament.

**Parameters:**

- `_token`: The address of the new stake token.

...

## 6. Transferring Funds to Yield Manager

### Function: `transferFundsToYieldManager() external`

This function is used to transfer funds to the yield manager for yield distribution.

...

## 7. Updating Yield Manager Balance After

### Function: `updateYieldManagerBalanceAfter(uint256 _amount) external`

This function is used to update the yield manager's balance after distributing rewards.

**Parameters:**

- `_amount`: The amount of funds distributed to participants.

...

## 8. Transferring Tournament Manager Role

### Function: `transferTournamentManager(address _newManager) external`

This function is used to transfer the tournament manager role to a new address.

**Parameters:**

- `_newManager`: The address of the new tournament manager.

...

## 9. Transferring Yield Manager Role

### Function: `transferYieldManager(address _newManager) external`

This function is used to transfer the yield manager role to a new address.

**Parameters:**

- `_newManager`: The address of the new yield manager.

...

## 10. Setting Player Placement

### Function: `setPlayerPlacement(address[] calldata _player, uint256[] calldata _placement) external`

This function is used to set the placement of players in the tournament.

**Parameters:**

- `_player`: An array of player addresses.
- `_placement`: An array of placement values corresponding to the players.

...

## 11. Depositing ERC20 Tokens

### Function: `depositERC20(address _token, uint256 _amount) external`

Allows a user to deposit ERC20 tokens into the tournament.

**Parameters:**

- `_token`: The address of the ERC20 token.
- `_amount`: The amount of tokens to deposit.

...

## 12. Locking Deposits

### Function: `lockDeposit(uint256 _amount) external`

This function is only called by the lock staking contract to deposit a player's locked staked tokens into the tournament.

**Parameters:**

- `_amount`: The amount of tokens to deposit.

...

## 13. Withdrawing Deposits

### Function: `withdraw(uint256 _amount) external`

Allows a user to withdraw deposited tokens from the tournament.

**Parameters:**

- `_amount`: The amount of tokens to withdraw.

...

## 14. Withdrawing Locked Tokens

### Function: `withdrawLocked(uint256 _amount) external`

This function is only called by the lock staking contract to withdraw a player's locked staked tokens from the tournament.

**Parameters:**

- `_amount`: The amount of tokens to withdraw.

...

## 15. Extending Tournament Duration

### Function: `extendTournament(uint8 _newTournamentEndTime) external returns (bool)`

This function is used to extend the duration of the current tournament.

**Parameters:**

- `_newTournamentEndTime`: The new end time for the tournament.

...

## 16. Getting Dashboard Stats

### Function: `getDashboardStats() external view returns (DashboardStats memory)`

This function is used to get the dashboard statistics of the tournament.

...

## 17. Getting Placement Reward Percentage

### Function: `getPlacementRewardPercentage() external view returns (uint256[] memory)`

This function is used to get the rewards (percentage) corresponding to the placement in the tournament.

...

...

## 18. Getting Tournament Info

### Function: `getTournamentInfo() external view returns (TournamentInfo memory)`

This function is used to get the settings and information of the current tournament.

...

## 19. Getting Player's Tournament Info

### Function: `getTournamentPlayersInfoByAddress(address _user) external view returns (PlayerInfo memory)`

This function is used to get the tournament information of a specific player.

**Parameters:**

- `_user`: The address of the player.

...

## 20. Getting Staked Amount by Address and Token ID

### Function: `getStakedAmountByAddressAndTokenID(address _user, uint256 _tokenID) external view returns (uint256)`

This function is used to retrieve the staked amount for a player by address and token ID.

**Parameters:**

- `_user`: The address of the player.
- `_tokenID`: The ID of the token.

...

## 21. Getting Locked Amount by Address and Token ID

### Function: `getLockedAmountByAddressAndTokenID(address _user, uint256 _tokenID) external view returns (uint256)`

This function is used to retrieve the locked amount for a player by address and token ID.

**Parameters:**

- `_user`: The address of the player.
- `_tokenID`: The ID of the token.

...

## 22. Creating a New Tournament

### Function: `newTournament(uint256 _startTimeStamp, uint256 _endTimeStamp, uint256 _minStake) external`

This function is used to create a new tournament with the specified start and end timestamps and the minimum stake amount required for participation.

**Parameters:**

- `_startTimeStamp`: The start timestamp of the tournament.
- `_endTimeStamp`: The end timestamp of the tournament.
- `_minStake`: The minimum stake amount required for participation in the tournament.

...

## 23. Getting TWAB Shares for Non-Top Players

### Function: `getTwabSharesForNonTopPlayers(uint256 _tokenID) public view returns (PlayerTwabInfo[] memory)`

This function retrieves TWAB shares for non-top players using a specific token ID.

**Parameters:**

- `_tokenID`: The ID of the token.

...

## 24. Getting Average Balance Between

### Function: `getAverageBalanceBetween(address _user, uint256 _tokenID, uint64 _startTime, uint64 _endTime) public view returns (uint256)`

This function is used to get the average balance held by a user during a specific time frame.

**Parameters:**

- `_user`: The address of the user.
- `_tokenID`: The ID of the token.
- `_startTime`: The start time of the time frame.
- `_endTime`: The end time of the time frame.

...

## 25. Getting Placement by Address

### Function: `getPlacementByAddress(address _user) public view returns (uint256)`

This function is used to get the placement of a player by address.

**Parameters:**

- `_user`: The address of the player.

...
