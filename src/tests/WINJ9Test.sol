// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "../WINJ9.sol";
import "../IWINJ9.sol";
import "../Bank.sol";

// Mock Bank Precompile Implementation
contract MockBankPrecompile {
    mapping(address => mapping(address => uint256)) private balances;
    mapping(address => uint256) private totalSupplies;
    mapping(address => string) private names;
    mapping(address => string) private symbols;
    mapping(address => uint8) private decimalsMap;

    function mint(address to, uint256 amount) external payable returns (bool) {
        // Get the token address from the caller (the WINJ9 contract)
        address token = msg.sender;
        balances[token][to] += amount;
        totalSupplies[token] += amount;
        return true;
    }

    function balanceOf(address token, address account) external view returns (uint256) {
        return balances[token][account];
    }

    function burn(address from, uint256 amount) external payable returns (bool) {
        // Get the token address from the caller (the WINJ9 contract)
        address token = msg.sender;
        require(balances[token][from] >= amount, "Insufficient balance");
        balances[token][from] -= amount;
        totalSupplies[token] -= amount;
        return true;
    }

    function transfer(address from, address to, uint256 amount) external payable returns (bool) {
        // Get the token address from the caller (the WINJ9 contract)
        address token = msg.sender;
        require(balances[token][from] >= amount, "Insufficient balance");
        balances[token][from] -= amount;
        balances[token][to] += amount;
        return true;
    }

    function totalSupply(address token) external view returns (uint256) {
        return totalSupplies[token];
    }

    function metadata(address token) external view returns (string memory, string memory, uint8) {
        return (names[token], symbols[token], decimalsMap[token]);
    }

    function setMetadata(string memory name_, string memory symbol_, uint8 decimals_) external payable returns (bool) {
        names[msg.sender] = name_;
        symbols[msg.sender] = symbol_;
        decimalsMap[msg.sender] = decimals_;
        return true;
    }
}

// Helper contracts for testing
contract ContractWithFallback {
    receive() external payable {}
    
    function withdrawFromWINJ9(address winj9Address, uint256 amount) external {
        IWINJ9(winj9Address).withdraw(amount);
    }
}

contract ContractWithoutFallback {
    function withdrawFromWINJ9(address winj9Address, uint256 amount) external {
        IWINJ9(winj9Address).withdraw(amount);
    }
}

contract ContractWithRevertingFallback {
    receive() external payable {
        revert("Fallback reverted");
    }
    
    function withdrawFromWINJ9(address winj9Address, uint256 amount) external {
        IWINJ9(winj9Address).withdraw(amount);
    }
}

contract ContractCaller {
    function depositToWINJ9(address winj9Address) external payable {
        IWINJ9(winj9Address).deposit{value: msg.value}();
    }
}

contract WINJ9Test is Test {
    WINJ9 public winj9;
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    
    uint256 public constant DEPOSIT_AMOUNT = 1 ether;
    uint256 public constant WITHDRAW_AMOUNT = 0.5 ether;
    uint256 public constant LARGE_AMOUNT = 1000 ether;

    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function setUp() public {
        // Deploy mock bank precompile
        MockBankPrecompile mockBank = new MockBankPrecompile();
        
        // Etch the mock precompile at the expected address
        address bankAddress = 0x0000000000000000000000000000000000000064;
        vm.etch(bankAddress, address(mockBank).code);
        
        // Deploy WINJ9 contract
        winj9 = new WINJ9{value: 0}("Wrapped INJ", "WINJ9", 18);
        
        // Fund test accounts with INJ
        vm.deal(alice, 10000 ether); // Increased for large deposit test
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
    }

    /***************************************************************************
     * Constructor Tests
    ****************************************************************************/

    function test_Constructor() public {
        assertEq(winj9.name(), "Wrapped INJ");
        assertEq(winj9.symbol(), "WINJ9");
        assertEq(winj9.decimals(), 18);
        assertEq(winj9.totalSupply(), 0);
    }

    /***************************************************************************
     * Deposit Tests
    ****************************************************************************/

    function test_Deposit() public {
        uint256 initialBalance = alice.balance;
        uint256 initialTotalSupply = winj9.totalSupply();
        
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        assertEq(winj9.balanceOf(alice), DEPOSIT_AMOUNT);
        assertEq(winj9.totalSupply(), initialTotalSupply + DEPOSIT_AMOUNT);
        assertEq(alice.balance, initialBalance - DEPOSIT_AMOUNT);
    }

    function test_Deposit_ZeroAmount() public {
        uint256 initialBalance = alice.balance;
        uint256 initialTotalSupply = winj9.totalSupply();
        
        vm.prank(alice);
        winj9.deposit{value: 0}();
        
        assertEq(winj9.balanceOf(alice), 0);
        assertEq(winj9.totalSupply(), initialTotalSupply);
        assertEq(alice.balance, initialBalance);
    }

    function test_Deposit_MultipleUsers() public {
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.prank(bob);
        winj9.deposit{value: DEPOSIT_AMOUNT * 2}();
        
        assertEq(winj9.balanceOf(alice), DEPOSIT_AMOUNT);
        assertEq(winj9.balanceOf(bob), DEPOSIT_AMOUNT * 2);
        assertEq(winj9.totalSupply(), DEPOSIT_AMOUNT * 3);
    }

    function test_Deposit_LargeAmount() public {
        // Should succeed since alice now has enough balance
        vm.prank(alice);
        winj9.deposit{value: LARGE_AMOUNT}();
        
        assertEq(winj9.balanceOf(alice), LARGE_AMOUNT);
        assertEq(winj9.totalSupply(), LARGE_AMOUNT);
    }

    function test_Deposit_EventEmitted() public {
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, DEPOSIT_AMOUNT);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
    }

    /***************************************************************************
     * Withdraw Tests
    ****************************************************************************/

    function test_Withdraw() public {
        // First deposit
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        uint256 initialBalance = alice.balance;
        uint256 initialTotalSupply = winj9.totalSupply();
        
        // Then withdraw
        vm.prank(alice);
        winj9.withdraw(WITHDRAW_AMOUNT);
        
        assertEq(winj9.balanceOf(alice), DEPOSIT_AMOUNT - WITHDRAW_AMOUNT);
        assertEq(winj9.totalSupply(), initialTotalSupply - WITHDRAW_AMOUNT);
        assertEq(alice.balance, initialBalance + WITHDRAW_AMOUNT);
    }

    function test_Withdraw_ZeroAmount() public {
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        uint256 initialBalance = alice.balance;
        uint256 initialTotalSupply = winj9.totalSupply();
        
        vm.prank(alice);
        winj9.withdraw(0);
        
        assertEq(winj9.balanceOf(alice), DEPOSIT_AMOUNT);
        assertEq(winj9.totalSupply(), initialTotalSupply);
        assertEq(alice.balance, initialBalance);
    }

    function test_Withdraw_EntireBalance() public {
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.prank(alice);
        winj9.withdraw(DEPOSIT_AMOUNT);
        
        assertEq(winj9.balanceOf(alice), 0);
        assertEq(winj9.totalSupply(), 0);
    }

    function test_Withdraw_InsufficientBalance() public {
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.prank(alice);
        vm.expectRevert("WINJ9: insufficient balance");
        winj9.withdraw(DEPOSIT_AMOUNT + 1);
    }

    function test_Withdraw_NoBalance() public {
        vm.prank(alice);
        vm.expectRevert("WINJ9: insufficient balance");
        winj9.withdraw(1);
    }

    function test_Withdraw_EventEmitted() public {
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(alice, WITHDRAW_AMOUNT);
        winj9.withdraw(WITHDRAW_AMOUNT);
    }

    /***************************************************************************
     * Receive Function Tests
    ****************************************************************************/

    function test_Receive() public {
        uint256 initialBalance = alice.balance;
        uint256 initialTotalSupply = winj9.totalSupply();
        
        vm.prank(alice);
        (bool success,) = address(winj9).call{value: DEPOSIT_AMOUNT}("");
        
        assertTrue(success);
        assertEq(winj9.balanceOf(alice), DEPOSIT_AMOUNT);
        assertEq(winj9.totalSupply(), initialTotalSupply + DEPOSIT_AMOUNT);
        assertEq(alice.balance, initialBalance - DEPOSIT_AMOUNT);
    }

    function test_Receive_ZeroAmount() public {
        uint256 initialBalance = alice.balance;
        uint256 initialTotalSupply = winj9.totalSupply();
        
        vm.prank(alice);
        (bool success,) = address(winj9).call{value: 0}("");
        
        assertTrue(success);
        assertEq(winj9.balanceOf(alice), 0);
        assertEq(winj9.totalSupply(), initialTotalSupply);
        assertEq(alice.balance, initialBalance);
    }

    /***************************************************************************
     * Integration Tests
    ****************************************************************************/

    function test_DepositAndWithdraw_CompleteCycle() public {
        // Deposit
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        // Transfer some tokens to bob
        vm.prank(alice);
        winj9.transfer(bob, WITHDRAW_AMOUNT);
        
        // Bob withdraws
        vm.prank(bob);
        winj9.withdraw(WITHDRAW_AMOUNT);
        
        assertEq(winj9.balanceOf(alice), DEPOSIT_AMOUNT - WITHDRAW_AMOUNT);
        assertEq(winj9.balanceOf(bob), 0);
        assertEq(winj9.totalSupply(), DEPOSIT_AMOUNT - WITHDRAW_AMOUNT);
    }

    function test_MultipleDepositsAndWithdrawals() public {
        // Alice deposits multiple times
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        // Alice withdraws partially
        vm.prank(alice);
        winj9.withdraw(WITHDRAW_AMOUNT);
        
        // Bob deposits
        vm.prank(bob);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        assertEq(winj9.balanceOf(alice), DEPOSIT_AMOUNT * 2 - WITHDRAW_AMOUNT);
        assertEq(winj9.balanceOf(bob), DEPOSIT_AMOUNT);
        assertEq(winj9.totalSupply(), DEPOSIT_AMOUNT * 3 - WITHDRAW_AMOUNT);
    }

    /***************************************************************************
     * Edge Cases and Error Handling
    ****************************************************************************/

    function test_Withdraw_ToContractWithFallback() public {
        // Deploy a contract that can receive INJ
        ContractWithFallback receiver = new ContractWithFallback();
        
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        // Transfer tokens to the contract
        vm.prank(alice);
        winj9.transfer(address(receiver), WITHDRAW_AMOUNT);
        
        // Contract withdraws
        vm.prank(address(receiver));
        winj9.withdraw(WITHDRAW_AMOUNT);
        
        assertEq(winj9.balanceOf(address(receiver)), 0);
        assertEq(address(receiver).balance, WITHDRAW_AMOUNT);
    }

    function test_Withdraw_ToContractWithoutFallback() public {
        // Deploy a contract without fallback
        ContractWithoutFallback receiver = new ContractWithoutFallback();
        
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        // Transfer tokens to the contract
        vm.prank(alice);
        winj9.transfer(address(receiver), WITHDRAW_AMOUNT);
        
        // Contract withdraws - should revert as expected
        vm.prank(address(receiver));
        vm.expectRevert("WINJ9: INJ transfer failed");
        winj9.withdraw(WITHDRAW_AMOUNT);
        
        // Optionally, check that balance remains unchanged
        assertEq(winj9.balanceOf(address(receiver)), WITHDRAW_AMOUNT);
        assertEq(address(receiver).balance, 0);
    }

    function test_Withdraw_ToContractWithRevertingFallback() public {
        // Deploy a contract with reverting fallback
        ContractWithRevertingFallback receiver = new ContractWithRevertingFallback();
        
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        // Transfer tokens to the contract
        vm.prank(alice);
        winj9.transfer(address(receiver), WITHDRAW_AMOUNT);
        
        // Contract withdraws - should fail
        vm.prank(address(receiver));
        vm.expectRevert("WINJ9: INJ transfer failed");
        winj9.withdraw(WITHDRAW_AMOUNT);
    }

    function test_Deposit_WithContractCall() public {
        // Test deposit through a contract call
        ContractCaller caller = new ContractCaller();
        
        vm.prank(alice);
        caller.depositToWINJ9{value: DEPOSIT_AMOUNT}(address(winj9));
        
        assertEq(winj9.balanceOf(address(caller)), DEPOSIT_AMOUNT);
    }

    /***************************************************************************
     * Gas Optimization Tests
    ****************************************************************************/

    function test_GasUsage_Deposit() public {
        uint256 gasBefore = gasleft();
        
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for deposit:", gasUsed);
        
        // Should be reasonable (less than 100k gas)
        assertLt(gasUsed, 100000);
    }

    function test_GasUsage_Withdraw() public {
        vm.prank(alice);
        winj9.deposit{value: DEPOSIT_AMOUNT}();
        
        uint256 gasBefore = gasleft();
        
        vm.prank(alice);
        winj9.withdraw(WITHDRAW_AMOUNT);
        
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for withdraw:", gasUsed);
        
        // Should be reasonable (less than 100k gas)
        assertLt(gasUsed, 100000);
    }

    /***************************************************************************
     * Interface Compliance Tests
    ****************************************************************************/

    function test_InterfaceCompliance() public {
        // Test that WINJ9 implements IWINJ9 correctly
        IWINJ9 winj9Interface = IWINJ9(address(winj9));
        
        vm.prank(alice);
        winj9Interface.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.prank(alice);
        winj9Interface.withdraw(WITHDRAW_AMOUNT);
        
        assertEq(winj9.balanceOf(alice), DEPOSIT_AMOUNT - WITHDRAW_AMOUNT);
    }

    /***************************************************************************
     * Mock Precompile Tests
    ****************************************************************************/

    function test_MockPrecompile_Integration() public {
        // Test that the mock precompile works correctly with WINJ9
        IBankModule bank = IBankModule(0x0000000000000000000000000000000000000064);
        
        // Test metadata
        (string memory name, string memory symbol, uint8 decimals) = bank.metadata(address(winj9));
        assertEq(name, "Wrapped INJ");
        assertEq(symbol, "WINJ9");
        assertEq(decimals, 18);
        
        // Test total supply
        assertEq(bank.totalSupply(address(winj9)), 0);
        
        // Test balance
        assertEq(bank.balanceOf(address(winj9), alice), 0);
    }
}