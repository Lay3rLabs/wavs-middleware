// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../src/WavsAVSRegistrar.sol";

contract WavsAVSRegistrarTest is Test {
    WavsAVSRegistrar public registrar;
    address public owner = address(0x1);
    address public nonOwner = address(0x2);

    function setUp() public {
        vm.startPrank(owner);
        registrar = new WavsAVSRegistrar();
        vm.stopPrank();
    }

    function test_initial_state() public view {
        // Test initial state
        assertEq(registrar.isPaused(), false, "Initial state should be unpaused");
        assertEq(registrar.owner(), owner, "Owner should be set correctly");
    }

    function test_pause() public {
        // Test pause functionality
        vm.prank(owner);
        registrar.pause();
        assertTrue(registrar.isPaused(), "Contract should be paused");
    }

    function test_unpause() public {
        // First pause the contract
        vm.prank(owner);
        registrar.pause();

        // Then unpause it
        vm.prank(owner);
        registrar.unpause();
        assertFalse(registrar.isPaused(), "Contract should be unpaused");
    }

    function test_only_owner_can_pause() public {
        // Non-owner should not be able to pause
        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        registrar.pause();
    }

    function test_only_owner_can_unpause() public {
        // First pause the contract
        vm.prank(owner);
        registrar.pause();

        // Non-owner should not be able to unpause
        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        registrar.unpause();
    }

    function test_registerOperator_works() public {
        address operator = address(0x123);
        address avs = address(0x456);
        uint32[] memory operatorSetIds = new uint32[](1);
        operatorSetIds[0] = 1;
        bytes memory data = "test data";

        // Should not revert when not paused
        registrar.registerOperator(operator, avs, operatorSetIds, data);
        assertTrue(true, "registerOperator should not revert when not paused");

        vm.prank(owner);
        registrar.pause();

        // Should revert with pause message when paused
        vm.expectRevert("AVSRegistrar: paused");
        registrar.registerOperator(operator, avs, operatorSetIds, data);
    }

    function test_deregisterOperator_works() public {
        address operator = address(0x123);
        address avs = address(0x456);
        uint32[] memory operatorSetIds = new uint32[](1);
        operatorSetIds[0] = 1;

        // Should not revert when not paused
        registrar.deregisterOperator(operator, avs, operatorSetIds);
        assertTrue(true, "deregisterOperator should not revert when not paused");

        vm.prank(owner);
        registrar.pause();

        // Should revert with pause message when paused
        vm.expectRevert("AVSRegistrar: paused");
        registrar.deregisterOperator(operator, avs, operatorSetIds);
    }
}
