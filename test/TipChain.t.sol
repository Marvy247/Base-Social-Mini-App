// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../src/TipChain.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract TipChainTest is Test {
    TipChain public tipChain;
    MockERC20 public token;
    address public alice;
    address public bob;

    function setUp() public {
        // Deploy TipChain contract with 0.001 ETH initial funding
        tipChain = (new TipChain){value: 0.001 ether}();
        token = new MockERC20();
        alice = vm.addr(1);
        bob = vm.addr(2);

        // Deal ETH and tokens to test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        token.transfer(alice, 1_000 ether);
        token.transfer(bob, 1_000 ether);

        // Fund the TipChain contract with some ERC20 tokens for withdrawals
        token.transfer(address(tipChain), 500 ether);
    }

    function testTipETH() public {
        vm.prank(alice);
        tipChain.tipETH{value: 1 ether}(1, bob);

        (uint256 length, address topTipper, uint256 topTipAmount) = tipChain.getChainStats(1);
        assertEq(length, 1);
        assertEq(topTipper, alice);
        assertEq(topTipAmount, 1 ether);

        uint256 recipientBalance = tipChain.recipientTips(bob, address(0));
        assertEq(recipientBalance, 1 ether);
    }

    function testTipERC20() public {
        vm.startPrank(alice);
        token.approve(address(tipChain), 100 ether);
        tipChain.tipERC20(1, bob, address(token), 10 ether);
        vm.stopPrank();

        (uint256 length, address topTipper, uint256 topTipAmount) = tipChain.getChainStats(1);
        assertEq(length, 1);
        assertEq(topTipper, alice);
        assertEq(topTipAmount, 10 ether);

        uint256 recipientBalance = tipChain.recipientTips(bob, address(token));
        assertEq(recipientBalance, 10 ether);
    }

    function testCannotTipTwice() public {
        vm.startPrank(alice);
        tipChain.tipETH{value: 1 ether}(1, bob);
        vm.expectRevert("Already tipped this chain"); // Updated error message
        tipChain.tipETH{value: 1 ether}(1, bob);
        vm.stopPrank();
    }

    function testWithdrawRecipientTipsERC20() public {
        vm.prank(alice);
        token.approve(address(tipChain), 50 ether);

        vm.prank(alice);
        tipChain.tipERC20(1, bob, address(token), 50 ether);

        uint256 before = token.balanceOf(bob);

        vm.prank(bob);
        tipChain.withdrawRecipientTips(address(token));

        uint256 afterBal = token.balanceOf(bob);
        assertEq(afterBal - before, 50 ether);
    }

    function testWithdrawUserTipsETH() public {
        vm.prank(alice);
        tipChain.tipETH{value: 3 ether}(1, bob);

        uint256 before = alice.balance;

        vm.prank(alice);
        tipChain.withdrawTips(address(0));

        uint256 afterBal = alice.balance;
        assertApproxEqAbs(afterBal - before, 3 ether, 1e14);
    }

    function testWithdrawUserTipsERC20() public {
        vm.prank(alice);
        token.approve(address(tipChain), 25 ether);

        vm.prank(alice);
        tipChain.tipERC20(1, bob, address(token), 25 ether);

        uint256 before = token.balanceOf(alice);

        vm.prank(alice);
        tipChain.withdrawTips(address(token));

        uint256 afterBal = token.balanceOf(alice);
        assertEq(afterBal - before, 0);
    }
}
