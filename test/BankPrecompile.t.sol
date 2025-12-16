// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/// @title IBankModule
/// @notice Interface for the Injective Bank precompile at address 0x64
interface IBankModule {
    /// @notice Mint tokens to a recipient
    function mint(address recipient, uint256 amount) external payable returns (bool);
    
    /// @notice Burn tokens from an account
    function burn(address account, uint256 amount) external payable returns (bool);
    
    /// @notice Get balance of an account for a token
    function balanceOf(address token, address account) external view returns (uint256);
    
    /// @notice Transfer tokens between addresses
    function transfer(address from, address to, uint256 amount) external payable returns (bool);
    
    /// @notice Get total supply of a token
    function totalSupply(address token) external view returns (uint256);
    
    /// @notice Get metadata of a token
    function metadata(address token) external view returns (string memory name, string memory symbol, uint8 decimals);
    
    /// @notice Set metadata for a token
    function setMetadata(string memory name, string memory symbol, uint8 decimals) external payable returns (bool);
}

contract BankPrecompileTest is Test {
    IBankModule bank = IBankModule(address(0x64));
    
    address token = address(0x1);
    address alice = address(0x100);
    address bob = address(0x200);
    address charlie = address(0x300);
    
    // Comprehensive test script that tells a story
    function run() public {
        console.log("=== Injective Bank Precompile Integration Test ===\n");
        
        // Setup: Set token metadata
        console.log("1. Setting up token metadata...");
        vm.prank(token);
        bool success = bank.setMetadata("Test Token", "TEST", 18);
        assertTrue(success, "Failed to set metadata");
        
        (string memory name, string memory symbol, uint8 decimals) = bank.metadata(token);
        console.log("   Token created: %s (%s) with %s decimals", name, symbol, decimals);
        assertEq(name, "Test Token");
        assertEq(symbol, "TEST");
        assertEq(decimals, 18);
        
        // Initial state checks
        console.log("\n2. Checking initial balances (should be zero)...");
        assertEq(bank.balanceOf(token, alice), 0, "Alice should start with 0");
        assertEq(bank.balanceOf(token, bob), 0, "Bob should start with 0");
        assertEq(bank.totalSupply(token), 0, "Total supply should be 0");
        console.log("   All balances start at zero [OK]");
        
        // Mint tokens to Alice
        console.log("\n3. Minting 10,000 tokens to Alice...");
        vm.prank(token);
        success = bank.mint(alice, 10000);
        assertTrue(success, "Failed to mint to Alice");
        
        uint256 aliceBalance = bank.balanceOf(token, alice);
        uint256 supply = bank.totalSupply(token);
        console.log("   Alice balance: %s", aliceBalance);
        console.log("   Total supply: %s", supply);
        assertEq(aliceBalance, 10000, "Alice should have 10000");
        assertEq(supply, 10000, "Supply should be 10000");
        
        // Mint tokens to Bob
        console.log("\n4. Minting 5,000 tokens to Bob...");
        vm.prank(token);
        success = bank.mint(bob, 5000);
        assertTrue(success, "Failed to mint to Bob");
        
        uint256 bobBalance = bank.balanceOf(token, bob);
        supply = bank.totalSupply(token);
        console.log("   Bob balance: %s", bobBalance);
        console.log("   Total supply: %s", supply);
        assertEq(bobBalance, 5000, "Bob should have 5000");
        assertEq(supply, 15000, "Supply should be 15000");
        
        // Transfer from Alice to Charlie
        console.log("\n5. Alice transfers 3,000 tokens to Charlie...");
        vm.prank(token);
        success = bank.transfer(alice, charlie, 3000);
        assertTrue(success, "Failed to transfer");
        
        aliceBalance = bank.balanceOf(token, alice);
        uint256 charlieBalance = bank.balanceOf(token, charlie);
        supply = bank.totalSupply(token);
        console.log("   Alice balance: %s", aliceBalance);
        console.log("   Charlie balance: %s", charlieBalance);
        console.log("   Total supply: %s (unchanged)", supply);
        assertEq(aliceBalance, 7000, "Alice should have 7000");
        assertEq(charlieBalance, 3000, "Charlie should have 3000");
        assertEq(supply, 15000, "Supply should still be 15000");
        
        // Burn tokens from Bob
        console.log("\n6. Burning 2,000 tokens from Bob...");
        vm.prank(token);
        success = bank.burn(bob, 2000);
        assertTrue(success, "Failed to burn");
        
        bobBalance = bank.balanceOf(token, bob);
        supply = bank.totalSupply(token);
        console.log("   Bob balance: %s", bobBalance);
        console.log("   Total supply: %s", supply);
        assertEq(bobBalance, 3000, "Bob should have 3000");
        assertEq(supply, 13000, "Supply should be 13000");
        
        // Transfer from Bob to Alice
        console.log("\n7. Bob transfers 1,000 tokens to Alice...");
        vm.prank(token);
        success = bank.transfer(bob, alice, 1000);
        assertTrue(success, "Failed to transfer");
        
        aliceBalance = bank.balanceOf(token, alice);
        bobBalance = bank.balanceOf(token, bob);
        console.log("   Alice balance: %s", aliceBalance);
        console.log("   Bob balance: %s", bobBalance);
        assertEq(aliceBalance, 8000, "Alice should have 8000");
        assertEq(bobBalance, 2000, "Bob should have 2000");
        
        // Final state summary
        console.log("\n8. Final state summary:");
        console.log("   ========================");
        console.log("   Alice:   %s tokens", bank.balanceOf(token, alice));
        console.log("   Bob:     %s tokens", bank.balanceOf(token, bob));
        console.log("   Charlie: %s tokens", bank.balanceOf(token, charlie));
        console.log("   ========================");
        console.log("   Total:   %s tokens", bank.totalSupply(token));
        
        // Verify final balances
        assertEq(bank.balanceOf(token, alice), 8000);
        assertEq(bank.balanceOf(token, bob), 2000);
        assertEq(bank.balanceOf(token, charlie), 3000);
        assertEq(bank.totalSupply(token), 13000);
        
        console.log("\n=== All operations completed successfully! ===");
    }
}
