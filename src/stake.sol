// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract StakingMining is Ownable {
    using SafeERC20 for IMintableERC20;

    struct StakeInfo {
        uint256 stakedAmount;  // 质押的RNT数量
        uint256 unclaimedRewards;  // 未领取的esRNT奖励
        uint256 lastUpdateTime;  // 上次更新的时间
    }

    struct UnlockInfo {
        uint256 esRNTBalance;  // 记录用户提交解锁的esRNT数量
        uint256 unlockStartTime;  // 记录解锁开始时间
    }

    IMintableERC20 public  esRNT;
    IMintableERC20 public  RNT;
    address public constant BURN_ADDRESS = address(0xdead); // 黑洞地址
    uint256 public constant REWARD_RATE = 1 ether; // 每天每个RNT奖励 1 esRNT
    uint256 public constant UNLOCK_PERIOD = 30 days; // 30天线性释放

    mapping(address => StakeInfo) public stakes;
    mapping(address => UnlockInfo) public unlocks;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event EsRNTUnlocked(address indexed user, uint256 amount);
    event RNTClaimed(address indexed user, uint256 claimedAmount, uint256 burnedAmount);

    constructor() Ownable(msg.sender) {}

    modifier updateRewards(address _user) {
        StakeInfo storage stake = stakes[_user];
        uint256 timeElapsed = block.timestamp - stake.lastUpdateTime;
        if (timeElapsed > 0 && stake.stakedAmount > 0) {
            stake.unclaimedRewards += (stake.stakedAmount * timeElapsed * REWARD_RATE) / 1 days;
        }
        stake.lastUpdateTime = block.timestamp;
        _;
    }

    function create(address _rnt, address _esRnt) public onlyOwner{
        RNT = IMintableERC20(_rnt);
        esRNT = IMintableERC20(_esRnt);
    }

    function stake(uint256 _amount) external updateRewards(msg.sender) {
        require(_amount > 0, "Amount must be greater than zero");
        RNT.safeTransferFrom(msg.sender, address(this), _amount);
        stakes[msg.sender].stakedAmount += _amount;
        stakes[msg.sender].lastUpdateTime = block.timestamp;
        emit Staked(msg.sender, _amount);
    }

    function unstake(uint256 _amount) external updateRewards(msg.sender) {
        require(_amount > 0, "Amount must be greater than zero");
        require(stakes[msg.sender].stakedAmount >= _amount, "Insufficient staked amount");
        stakes[msg.sender].stakedAmount -= _amount;
        RNT.safeTransfer(msg.sender, _amount);
        emit Unstaked(msg.sender, _amount);
    }

    function claimRewards() external updateRewards(msg.sender) {
        uint256 reward = stakes[msg.sender].unclaimedRewards;
        require(reward > 0, "No rewards to claim");
        stakes[msg.sender].unclaimedRewards = 0;
        esRNT.mint(msg.sender, reward);
        emit RewardsClaimed(msg.sender, reward);
    }

    function unlockEsRNT(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        esRNT.safeTransferFrom(msg.sender, address(this), _amount);
        unlocks[msg.sender].esRNTBalance += _amount;
        unlocks[msg.sender].unlockStartTime = block.timestamp;
        emit EsRNTUnlocked(msg.sender, _amount);
    }

    function claimRNT() external {
        UnlockInfo storage unlock = unlocks[msg.sender];
        require(unlock.esRNTBalance > 0, "No esRNT to claim");

        uint256 timeElapsed = block.timestamp - unlock.unlockStartTime;
        if (timeElapsed > UNLOCK_PERIOD) {
            timeElapsed = UNLOCK_PERIOD; // 限制最大时间为30天
        }

        uint256 unlocked = (unlock.esRNTBalance * timeElapsed) / UNLOCK_PERIOD;
        uint256 burned = unlock.esRNTBalance - unlocked;

        if (unlocked > 0) {
            RNT.mint(msg.sender, unlocked); // mint 对应的 RNT
        }

        unlock.esRNTBalance = 0;
        unlock.unlockStartTime = 0;

        emit RNTClaimed(msg.sender, unlocked, burned);
    }
}
