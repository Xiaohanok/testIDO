// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/IDO.sol";
import "../src/RNTToken.sol";

contract IDOPresaleTest is Test {
    IDOPresale idoPresale;
    RNTToken token;
    address owner = address(0x856);
    address user1 = address(0x123);
    address user2 = address(0x456);
    uint256 startTime;
    uint256 endTime;

    function setUp() public {
        startTime = block.timestamp + 1; // 预售开始时间设为未来
        endTime = startTime + 1 days;    // 预售持续一天
        vm.startPrank(owner);
        idoPresale = new IDOPresale();
        token = new RNTToken(address(idoPresale),address(0x123456));
        idoPresale.createPresale(address(token),startTime, endTime);
        vm.stopPrank();
    }

    function testParticipate() public {
        vm.warp(startTime);
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        idoPresale.participate{value: 0.05 ether}();

        (uint256 softCap1, uint256 hardCap1, uint256 startTime1, uint256 endTime1, uint256 totalCollected1) = idoPresale.getPresaleInfo();
        assertEq(totalCollected1, 0.05 ether);
        assertEq(idoPresale.getContribution(user1), 0.05 ether);
    }


    function testRefund() public {
        vm.warp(startTime);
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        idoPresale.participate{value: 0.05 ether}();
        assertEq(user1.balance, 0.95 ether);

        vm.warp(endTime + 1);

        idoPresale.refund();
        assertEq(user1.balance, 1 ether);
        vm.stopPrank();
    }


function testClaimTokens() public {
    vm.warp(startTime);

    // 模拟 1000 个用户，每个用户存款 0.1 ETH，确保 totalCollected = 100 ETH (softCap)
    for (uint256 i = 1; i <= 1000; i++) {
        address user = address(uint160(i)); // 生成不同的地址
        vm.deal(user, 1 ether); // 给每个用户分配足够的 ETH
        
        vm.prank(user);
        idoPresale.participate{value: 0.1 ether}(); // 每个用户存 0.1 ETH
    }

    // 预售结束
    vm.warp(endTime + 1);

    // Owner 提取 ETH
    vm.startPrank(owner);
    assertEq(address(idoPresale).balance, 100 ether);
    idoPresale.withdrawETH();
    assertEq(owner.balance, 100 ether);

    vm.stopPrank();

    // 每个用户领取代币 (只测试前 5 个)
    for (uint256 i = 1; i <= 5; i++) {
        address user = address(uint160(i));

        vm.startPrank(user);
        idoPresale.claimTokens();
        vm.stopPrank();
    }
}




}