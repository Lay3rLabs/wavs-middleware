// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {WavsServiceManager} from "src/eigenlayer/bls/WavsServiceManager.sol";
import {IWavsServiceManager} from "src/eigenlayer/bls/interfaces/IWavsServiceManager.sol";

/**
 * @title WavsServiceManagerTest
 * @author Lay3rLabs
 * @notice This contract contains tests for the WavsServiceManager contract.
 * @dev This contract is used to test the WavsServiceManager contract.
 */
contract WavsServiceManagerTest is Test {
    /// @notice The service manager.
    WavsServiceManager public serviceManager;
    /// @notice The owner.
    address public owner = makeAddr("owner");
    /// @notice The proxy owner.
    address public proxyOwner = makeAddr("proxyOwner");

    /// @notice The AVS directory.
    address public avsDirectory = makeAddr("avsDirectory");
    /// @notice The rewards coordinator.
    address public rewardsCoordinator = makeAddr("rewardsCoordinator");
    /// @notice The registry coordinator.
    address public registryCoordinator = makeAddr("registryCoordinator");
    /// @notice The stake registry.
    address public stakeRegistry = makeAddr("stakeRegistry");
    /// @notice The permission controller.
    address public permissionController = makeAddr("permissionController");
    /// @notice The allocation manager.
    address public allocationManager = makeAddr("allocationManager");

    /// @notice The setUp function.
    function setUp() public {
        // Set the owner as the caller for all subsequent calls in this test
        vm.startPrank(owner);

        // Deploy the implementation contract
        WavsServiceManager implementation = new WavsServiceManager(
            avsDirectory,
            rewardsCoordinator,
            registryCoordinator,
            stakeRegistry,
            permissionController,
            allocationManager
        );
        vm.stopPrank();

        vm.startPrank(proxyOwner);
        // Deploy the proxy and initialize it
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            proxyOwner,
            abi.encodeWithSelector(WavsServiceManager.initialize.selector, owner, owner)
        );
        serviceManager = WavsServiceManager(address(proxy));
        vm.stopPrank();
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_initial_state function.
    function test_initial_state() public view {
        // Test initial state
        assertEq(serviceManager.quorumNumerator(), 2, "Initial quorum numerator should be 2");
        assertEq(serviceManager.quorumDenominator(), 3, "Initial quorum denominator should be 3");
        assertEq(serviceManager.avsDirectory(), avsDirectory, "AVS directory should be set");
    }

    /// @notice The test_setQuorumThreshold function.
    function test_setQuorumThreshold() public {
        // Change quorum to 51%
        vm.startPrank(owner);
        serviceManager.setQuorumThreshold(51, 100);
        vm.stopPrank();

        assertEq(serviceManager.quorumNumerator(), 51, "Quorum numerator should be updated");
        assertEq(serviceManager.quorumDenominator(), 100, "Quorum denominator should be updated");
    }

    /// @notice The test_setQuorumThreshold_only_owner function.
    function test_setQuorumThreshold_only_owner() public {
        // Non-owner should not be able to set quorum threshold
        vm.prank(makeAddr("non-owner"));
        vm.expectRevert("Ownable: caller is not the owner");
        serviceManager.setQuorumThreshold(1, 2);
    }

    /// @notice The test_setQuorumThreshold_invalid_params function.
    function test_setQuorumThreshold_invalid_params() public {
        // numerator = 0
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IWavsServiceManager.InvalidQuorumParameters.selector)
        );
        serviceManager.setQuorumThreshold(0, 2);

        // denominator = 0
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IWavsServiceManager.InvalidQuorumParameters.selector)
        );
        serviceManager.setQuorumThreshold(1, 0);

        // numerator > denominator
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IWavsServiceManager.InvalidQuorumParameters.selector)
        );
        serviceManager.setQuorumThreshold(3, 2);
    }

    /// @notice The test_setServiceURI function.
    function test_setServiceURI() public {
        vm.startPrank(owner);
        serviceManager.setServiceURI("https://wavs.io");
        vm.stopPrank();

        assertEq(serviceManager.getServiceURI(), "https://wavs.io", "Service URI should be updated");

        vm.startPrank(makeAddr("non-owner"));
        vm.expectRevert("Ownable: caller is not the owner");
        serviceManager.setServiceURI("https://wavs.io");
        vm.stopPrank();
    }
}
