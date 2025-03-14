// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRNTToken is IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract IDOPresale is Ownable {
    struct Presale {
        uint256 softCap; // 募集目标 (100 ETH)
        uint256 hardCap; // 募集上限 (200 ETH)
        uint256 startTime;
        uint256 endTime;
        uint256 totalCollected;
        mapping(address => uint256) contributions;
    }

    Presale public presale;
    address public projectOwner;
    IRNTToken public token;
    uint256 public constant MIN_CONTRIBUTION = 0.01 ether;
    uint256 public constant MAX_CONTRIBUTION = 0.1 ether;
    uint256 public constant TOTAL_TOKENS_FOR_SALE = 1_000_000 * 1e18;
    
    event PresaleCreated(uint256 softCap, uint256 hardCap, uint256 startTime, uint256 endTime);
    event ContributionReceived(address indexed user, uint256 amount);
    event Refunded(address indexed user, uint256 amount);
    event TokensClaimed(address indexed user, uint256 amount);
    event ETHWithdrawn(address indexed owner, uint256 amount);

    modifier onlyDuringPresale() {
        require(block.timestamp >= presale.startTime && block.timestamp <= presale.endTime, "Presale not active");
        _;
    }

    modifier onlyAfterPresale() {
        require(block.timestamp > presale.endTime, "Presale not ended");
        _;
    }

    modifier onlySuccess() {
        require(presale.totalCollected >= presale.softCap, "Presale failed");
        _;
    }

    constructor() Ownable(msg.sender) {
        projectOwner = msg.sender;
    }

    function createPresale(
        address _token,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner {
        require(_endTime > _startTime, "Invalid presale time");
        token = IRNTToken(_token); 
        presale.softCap = 100 ether;
        presale.hardCap = 200 ether;
        presale.startTime = _startTime;
        presale.endTime = _endTime;
        presale.totalCollected = 0;

        emit PresaleCreated(presale.softCap, presale.hardCap, _startTime, _endTime);
    }

    function participate() external payable onlyDuringPresale {
        require(msg.value >= MIN_CONTRIBUTION && msg.value <= MAX_CONTRIBUTION, "Invalid contribution amount");
        require(presale.totalCollected + msg.value <= presale.hardCap, "Exceeds hard cap");
        require(presale.contributions[msg.sender] + msg.value <= MAX_CONTRIBUTION, "Exceeds max contribution per address");

        presale.contributions[msg.sender] += msg.value;
        presale.totalCollected += msg.value;
        emit ContributionReceived(msg.sender, msg.value);
    }

    function claimTokens() external onlyAfterPresale onlySuccess {
        uint256 contributed = presale.contributions[msg.sender];
        require(contributed > 0, "No contribution");
        
        uint256 tokenAmount = (contributed * TOTAL_TOKENS_FOR_SALE) / presale.totalCollected;
        presale.contributions[msg.sender] = 0;
        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");
        
        emit TokensClaimed(msg.sender, tokenAmount);
    }

    function refund() external onlyAfterPresale {
        require(presale.totalCollected < presale.softCap, "Presale succeeded");
        uint256 contributed = presale.contributions[msg.sender];
        require(contributed > 0, "No contribution");
        
        presale.contributions[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: contributed}("");
        require(success, "Refund transfer failed");
    }

        function withdrawETH() external onlyAfterPresale onlyOwner onlySuccess {
        uint256 amount = address(this).balance;
        (bool success, ) = payable(projectOwner).call{value: amount}("");
        require(success, "ETH withdrawal failed");
        
        emit ETHWithdrawn(projectOwner, amount);
    }

    function getPresaleInfo() external view returns (
    uint256 softCap,
    uint256 hardCap,
    uint256 startTime,
    uint256 endTime,
    uint256 totalCollected
)   {
        return (
            presale.softCap,
            presale.hardCap,
            presale.startTime,
            presale.endTime,
            presale.totalCollected
        );
    }

    function getContribution(address user) external view returns (uint256) {
        return presale.contributions[user];
    }


}