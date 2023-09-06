// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import "./ITournament.sol";

contract LockStaking {
    using SafeMath for uint256;
    uint8 private _decimals;
    uint256 tokenID;
    address public immutable tournamentAddress;
    ITournament public immutable tournament;
    IERC20 public immutable token;
    mapping(uint => uint) public lockduration;
    mapping(address => uint) public accountlockcounter;
    mapping(address => uint) public accounttotallock;
    mapping(address => mapping(uint => uint)) public accountlockduration;
    mapping(address => mapping(uint => uint)) public accountlockamount;
    mapping(address => mapping(uint => bool)) public accountlockclaimed;
    string private _name;
    string private _symbol;

    event LockDeposit(
        address indexed owner,
        uint256 id,
        uint256 amount,
        uint256 releasetime
    );

    event UnlockAndWithdraw(
        address indexed owner,
        uint256 indexed amount,
        uint256 indexed counter
    );

    constructor(address _tournament, address _token, uint256 _tokenID) {
        lockduration[1] = 7776000; //3 Months
        lockduration[2] = 15780000; //6 Months
        lockduration[3] = 31536000; // 12 Months

        tournamentAddress = _tournament;
        tournament = ITournament(_tournament);
        token = IERC20(_token);
        tokenID = _tokenID;
    }

    function lock(uint _selection, uint _amount) external {
        require(_amount > 0, "Nothing to deposit");
        uint locktime = lockduration[_selection].add(block.timestamp);
        accountlockcounter[msg.sender] += 1;
        accountlockduration[msg.sender][
            accountlockcounter[msg.sender]
        ] = locktime;
        accountlockamount[msg.sender][accountlockcounter[msg.sender]] = _amount;
        accounttotallock[msg.sender] += _amount;

        token.transferFrom(msg.sender, address(this), _amount);
        token.approve(tournamentAddress, _amount);
        tournament.lockDeposit(tokenID, _amount);

        emit LockDeposit(
            msg.sender,
            accountlockcounter[msg.sender],
            _amount,
            locktime
        );
    }

    function unlock(uint _counter) external {
        require(accountlockamount[msg.sender][_counter] > 0, "No amount lock");
        require(
            block.timestamp >= accountlockduration[msg.sender][_counter],
            "Not ready to unlock"
        );
        require(accountlockclaimed[msg.sender][_counter] == false, "Claimed");

        accountlockclaimed[msg.sender][_counter] = true;
        accounttotallock[msg.sender] -= accountlockamount[msg.sender][_counter];

        tournament.withdrawLocked(
            tokenID,
            accountlockamount[msg.sender][_counter]
        );

        emit UnlockAndWithdraw(
            msg.sender,
            accountlockamount[msg.sender][_counter],
            _counter
        );
    }
}
