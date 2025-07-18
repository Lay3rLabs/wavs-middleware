// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {WavsAVSRegistrar} from "src/eigenlayer/ecdsa/WavsAVSRegistrar.sol";

/**
 * @title WavsAVSRegistrarTest
 * @author Lay3rLabs
 * @notice This contract contains tests for the WavsAVSRegistrar contract.
 * @dev This contract is used to test the WavsAVSRegistrar contract.
 */
contract WavsAVSRegistrarTest is Test {
    /// @notice The registrar.
    WavsAVSRegistrar public registrar;
    /// @notice The owner.
    address public owner = address(0x1);
    /// @notice The non-owner.
    address public nonOwner = address(0x2);

    /// @notice The setUp function.
    function setUp() public {
        vm.startPrank(owner);
        registrar = new WavsAVSRegistrar();
        vm.stopPrank();
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_initial_state function.
    function test_initial_state() public view {
        /* solhint-enable func-name-mixedcase */
        // Test initial state
        assertEq(registrar.isPaused(), false, "Initial state should be unpaused");
        assertEq(registrar.owner(), owner, "Owner should be set correctly");
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_pause function.
    function test_pause() public {
        /* solhint-enable func-name-mixedcase */
        // Test pause functionality
        vm.prank(owner);
        registrar.pause();
        assertTrue(registrar.isPaused(), "Contract should be paused");
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_unpause function.
    function test_unpause() public {
        /* solhint-enable func-name-mixedcase */
        // First pause the contract
        vm.prank(owner);
        registrar.pause();

        // Then unpause it
        vm.prank(owner);
        registrar.unpause();
        assertFalse(registrar.isPaused(), "Contract should be unpaused");
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_only_owner_can_pause function.
    function test_only_owner_can_pause() public {
        /* solhint-enable func-name-mixedcase */
        // Non-owner should not be able to pause
        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        registrar.pause();
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_only_owner_can_unpause function.
    function test_only_owner_can_unpause() public {
        /* solhint-enable func-name-mixedcase */
        // First pause the contract
        vm.prank(owner);
        registrar.pause();

        // Non-owner should not be able to unpause
        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        registrar.unpause();
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_registerOperator_works function.
    function test_registerOperator_works() public {
        /* solhint-enable func-name-mixedcase */
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
        vm.expectRevert(abi.encodeWithSelector(WavsAVSRegistrar.WavsAVSRegistrar__Paused.selector));
        registrar.registerOperator(operator, avs, operatorSetIds, data);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_deregisterOperator_works function.
    function test_deregisterOperator_works() public {
        /* solhint-enable func-name-mixedcase */
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
        vm.expectRevert(abi.encodeWithSelector(WavsAVSRegistrar.WavsAVSRegistrar__Paused.selector));
        registrar.deregisterOperator(operator, avs, operatorSetIds);
    }
}
