// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "forge-std/Test.sol";
import "../src/W3CXII.sol";

contract ExploitHelper {
    constructor(address _target) payable {
        selfdestruct(payable(_target));
    }
}


contract ETHRejecter {
    receive() external payable {
        revert("I reject ETH");
    }
    
    function depositAndWithdraw(W3CXII target) external payable {
        target.deposit{value: 0.5 ether}();
        target.withdraw();
    }
}

contract W3CXIITest is Test {
    W3CXII public target;
    address public user = makeAddr("user");
    address public attacker = makeAddr("attacker");
    
    function setUp() public {
        target = new W3CXII{value: 1 ether}();
        vm.deal(user, 2 ether);
        vm.deal(attacker, 20 ether);
    }
    
    function test_constructor() public view {
        assertEq(address(target).balance, 1 ether);
    }
    
    function test_deposit_success() public {
        vm.prank(user);
        target.deposit{value: 0.5 ether}();
        assertEq(target.balanceOf(user), 0.5 ether);
    }
    
    function test_deposit_invalidAmount() public {
        vm.prank(user);
        vm.expectRevert("InvalidAmount");
        target.deposit{value: 0.1 ether}();
    }
    
    function test_deposit_maxExceeded() public {
        
        W3CXII localTarget = new W3CXII{value: 0.5 ether}();
        
        vm.store(
            address(localTarget),
            keccak256(abi.encode(user, uint256(1))),
            bytes32(uint256(0.6 ether))
        );
        
        assertEq(localTarget.balanceOf(user), 0.6 ether);
        
        vm.prank(user);
        vm.expectRevert("Max deposit exceeded");
        localTarget.deposit{value: 0.5 ether}();
    }
    
    function test_deposit_locked() public {

        new ExploitHelper{value: 1 ether}(address(target));
        assertEq(address(target).balance, 2 ether);
        
        vm.prank(user);
        vm.expectRevert("deposit locked");
        target.deposit{value: 0.5 ether}();
    }
    
    function test_withdraw_normal() public {
        vm.prank(user);
        target.deposit{value: 0.5 ether}();
        
        uint256 initialBalance = user.balance;
        vm.prank(user);
        target.withdraw();
        
        assertEq(user.balance, initialBalance + 0.5 ether);
        assertEq(target.balanceOf(user), 0);
    }
    
    function test_withdraw_noDeposit() public {
        vm.prank(user);
        vm.expectRevert("No deposit");
        target.withdraw();
    }
    
    function test_withdraw_dosed() public {
        vm.prank(user);
        target.deposit{value: 0.5 ether}();
        
        vm.prank(attacker);
        new ExploitHelper{value: 18.5 ether}(address(target));
        
        vm.prank(user);
        target.withdraw();
        
        assertTrue(target.dosed());
        assertEq(target.balanceOf(user), 0.5 ether);
    }
    
    function test_withdraw_transferFailed() public {
        ETHRejecter rejecter = new ETHRejecter();
        vm.deal(address(rejecter), 0.5 ether);
        
        
        vm.prank(address(rejecter));
        target.deposit{value: 0.5 ether}();
        
        vm.expectRevert("Transfer failed");
        vm.prank(address(rejecter));
        target.withdraw();
    }
    
    function test_dest_reverts() public {
        vm.prank(user);
        vm.expectRevert("Not dosed");
        target.dest();
    }
    
    function test_dest_success() public {
        vm.prank(user);
        target.deposit{value: 0.5 ether}();
        
        vm.prank(attacker);
        new ExploitHelper{value: 18.5 ether}(address(target));
        
        vm.prank(user);
        target.withdraw();
        
        uint256 contractBalance = address(target).balance;
        uint256 userBalanceBefore = user.balance;
        
        vm.prank(user);
        target.dest();
        
        assertEq(user.balance, userBalanceBefore + contractBalance);
    }
}