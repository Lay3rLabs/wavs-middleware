// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {WavsServiceManager} from "src/eigenlayer/bls/WavsServiceManager.sol";
import {IWavsServiceManager} from "src/eigenlayer/bls/interfaces/IWavsServiceManager.sol";

contract WavsServiceManagerTest is Test {
    WavsServiceManager public serviceManager;
    address public owner = makeAddr("owner");
    address public proxyOwner = makeAddr("proxyOwner");

    address public avsDirectory = makeAddr("avsDirectory");
    address public rewardsCoordinator = makeAddr("rewardsCoordinator");
    address public registryCoordinator = makeAddr("registryCoordinator");
    address public stakeRegistry = makeAddr("stakeRegistry");
    address public permissionController = makeAddr("permissionController");
    address public allocationManager = makeAddr("allocationManager");

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

    function test_initial_state() public view {
        // Test initial state
        assertEq(serviceManager.quorumNumerator(), 2, "Initial quorum numerator should be 2");
        assertEq(serviceManager.quorumDenominator(), 3, "Initial quorum denominator should be 3");
        assertEq(serviceManager.avsDirectory(), avsDirectory, "AVS directory should be set");
    }

    function test_setQuorumThreshold() public {
        // Change quorum to 51%
        vm.startPrank(owner);
        serviceManager.setQuorumThreshold(51, 100);
        vm.stopPrank();

        assertEq(serviceManager.quorumNumerator(), 51, "Quorum numerator should be updated");
        assertEq(serviceManager.quorumDenominator(), 100, "Quorum denominator should be updated");
    }

    function test_setQuorumThreshold_only_owner() public {
        // Non-owner should not be able to set quorum threshold
        vm.prank(makeAddr("non-owner"));
        vm.expectRevert("Ownable: caller is not the owner");
        serviceManager.setQuorumThreshold(1, 2);
    }

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
