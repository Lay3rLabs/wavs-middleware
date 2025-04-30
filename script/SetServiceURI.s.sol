// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {WavsServiceManager} from "../src/WavsServiceManager.sol";

/**
 * @title SetServiceURI
 * @notice A Forge script to set the service URI for the WAVS service manager
 * @dev This script replaces the docker/set_service_uri.sh bash script
 */
contract SetServiceURI is Script {
    using Strings for *;

    // Contract addresses
    address private serviceManagerAddress;

    // Service URI
    string private serviceUri;

    // Deployment key
    uint256 private deployerPrivateKey;
    address private deployer;

    function setUp() public {
        // Check service URI from script args
        string memory serviceUriArg = vm.envOr("SERVICE_URI", string(""));
        if (bytes(serviceUriArg).length == 0) {
            revert(
                "SERVICE_URI environment variable or script argument is required"
            );
        }
        serviceUri = serviceUriArg;

        // Get deployer key
        string memory deployerKeyPath = string.concat(
            vm.projectRoot(),
            "/../.nodes/deployer"
        );
        if (!vm.exists(deployerKeyPath)) {
            deployerKeyPath = string.concat(
                vm.projectRoot(),
                "/.nodes/deployer"
            );
            if (!vm.exists(deployerKeyPath)) {
                // Last resort - try environment variable
                deployerPrivateKey = vm.envOr("FUNDED_KEY", uint256(0));
                if (deployerPrivateKey == 0) {
                    revert(
                        "Deployer key not found. Please set FUNDED_KEY or ensure .nodes/deployer exists"
                    );
                }
            } else {
                // Read key from file
                string memory keyHex = vm.readLine(deployerKeyPath);
                deployerPrivateKey = vm.parseUint(keyHex);
            }
        } else {
            // Read key from file
            string memory keyHex = vm.readLine(deployerKeyPath);
            deployerPrivateKey = vm.parseUint(keyHex);
        }
        deployer = vm.addr(deployerPrivateKey);
        console2.log("Deployer address:", deployer);

        // Read contract addresses from deployment file
        string memory deploymentPath = string.concat(
            vm.projectRoot(),
            "/deployments/wavs-middleware/",
            vm.toString(block.chainid),
            ".json"
        );

        // If the deployment file doesn't exist, try the .nodes/avs_deploy.json path
        if (!vm.exists(deploymentPath)) {
            deploymentPath = string.concat(
                vm.projectRoot(),
                "/../.nodes/avs_deploy.json"
            );

            // Fail if neither file exists
            if (!vm.exists(deploymentPath)) {
                revert("Deployment file not found");
            }
        }

        // Parse the JSON to get the service manager address
        string memory json = vm.readFile(deploymentPath);
        serviceManagerAddress = vm.parseJsonAddress(
            json,
            ".addresses.WavsServiceManager"
        );
        if (serviceManagerAddress == address(0)) {
            revert("Failed to read WavsServiceManager address");
        }
    }

    function run() external {
        console2.log("=== WAVS Service Manager ===");
        console2.log("Contract Address:", serviceManagerAddress);
        console2.log("Setting service URI to:", serviceUri);

        // Get owner of service manager
        address owner = WavsServiceManager(serviceManagerAddress).owner();
        console2.log("Owner address:", owner);

        // Determine if we need to impersonate the owner
        bool needsImpersonation = owner != deployer;
        if (needsImpersonation) {
            console2.log("Impersonating owner for transaction");
            vm.startBroadcast(deployerPrivateKey);
            vm.startPrank(owner);
        } else {
            vm.startBroadcast(deployerPrivateKey);
        }

        // Set the service URI
        WavsServiceManager(serviceManagerAddress).setServiceURI(serviceUri);

        // End impersonation if needed
        if (needsImpersonation) {
            vm.stopPrank();
        }

        vm.stopBroadcast();

        // Verify the service URI was set
        string memory newServiceUri = WavsServiceManager(serviceManagerAddress)
            .getServiceURI();
        console2.log("New service URI set:", newServiceUri);
        console2.log("Service URI updated successfully");
    }
}
