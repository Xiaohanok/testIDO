// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/RNTToken.sol";
import "../src/esRNTToken.sol";
import "../src/stake.sol";

contract StakingMiningTest is Test {
    RNTToken rntToken;
    esRNTToken esRNT;
    StakingMining stakingMining;

    address user = address(0x123); // 测试用户地址
    address owner = address(0x456);
    address ido = address(0x789);
    function setUp() public {
        // 部署 RNTToken 和 esRNTToken 合约
        vm.startPrank(owner);
        stakingMining = new StakingMining();
        rntToken = new RNTToken(ido, address(stakingMining));
        esRNT = new esRNTToken(address(stakingMining));
        
        
        // 连接 RNT 和 esRNT 合约
        stakingMining.create(address(rntToken), address(esRNT));
        vm.stopPrank();
        
        // 为测试用户铸造 RNT 代币
        vm.prank(ido);
        rntToken.transfer(user, 100 * 1e18); // 铸造 100 RNT

    }

    function testStake() public {
        uint256 stakeAmount = 100 * 1e18; // 100 RNT
        vm.startPrank(user); // 模拟用户操作
        rntToken.approve(address(stakingMining), stakeAmount); // 授权 staking 合约使用 RNT
        stakingMining.stake(stakeAmount); // 进行质押

        // 检查质押金额
        (uint256 stakedAmount, , ) = stakingMining.stakes(user);
        assertEq(stakedAmount, stakeAmount, "no");
        vm.stopPrank();
    }

    function testUnstake() public {
        uint256 stakeAmount = 50 * 1e18;
        vm.startPrank(user);
        rntToken.approve(address(stakingMining), stakeAmount);
        stakingMining.stake(stakeAmount);
        stakingMining.unstake(stakeAmount);
        vm.stopPrank();
        (uint256 stakedAmount, , ) = stakingMining.stakes(user);
        assertEq(stakedAmount, 0 ,"Unstaking failed");
        assertEq(rntToken.balanceOf(user), 100 * 1e18, "Balance incorrect after unstaking");
    }


    function testRewardAccumulation() public {
        uint256 stakeAmount = 100 * 1e18;
        vm.startPrank(user);
        rntToken.approve(address(stakingMining), stakeAmount);
        stakingMining.stake(stakeAmount);
        vm.warp(block.timestamp + 1 days);
        stakingMining.claimRewards();
        esRNT.approve(address(stakingMining), 100 * 1e18);
        stakingMining.unlockEsRNT(100 * 1e18);
        vm.warp(block.timestamp + 30 days);
        stakingMining.claimRNT();
        vm.stopPrank();
        assertGt(rntToken.balanceOf(user), 0, "Rewards not accumulating");

    }

} 