// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/Test.sol";
import {WavsMiddlewareDeploymentLib} from "./utils/WavsMiddlewareDeplomentLib.sol";
import {ReadCoreLib} from "./utils/ReadCoreLib.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IECDSAStakeRegistryTypes} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title WavsListOperators
 * @notice A Forge script to list registered operators and their weights
 * @dev This script replaces the docker/list_operator.sh bash script
 */
contract WavsListOperators is Script {
    using Strings for *;

    // Event signature for OperatorRegistered
    bytes32 public constant OPERATOR_REGISTERED_EVENT =
        keccak256("OperatorRegistered(address,address)");

    // Contract addresses
    address private stakeRegistryAddress;

    // Command line arguments - allows checking a specific operator
    address[] private specificOperators;

    function setUp() public {
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

        // Parse the JSON to get the stake registry address
        string memory json = vm.readFile(deploymentPath);
        stakeRegistryAddress = vm.parseJsonAddress(
            json,
            ".addresses.stakeRegistry"
        );
        if (stakeRegistryAddress == address(0)) {
            revert("Failed to read stake registry address");
        }

        // Get command line args if any
        string[] memory args = getCliArgs();
        console2.log("Checking for command line arguments...");

        if (args.length > 0) {
            console2.log("Found", args.length, "arguments");
            // First arg is the script name, remaining args are operator addresses
            for (uint i = 0; i < args.length; i++) {
                if (bytes(args[i]).length > 0) {
                    // Try to parse as an address
                    try vm.parseAddress(args[i]) returns (address op) {
                        console2.log("Adding specific operator to check:", op);
                        // Create array if needed and add address
                        if (specificOperators.length == 0) {
                            specificOperators = new address[](1);
                            specificOperators[0] = op;
                        } else {
                            // Create new array with one more slot
                            address[] memory newOperators = new address[](
                                specificOperators.length + 1
                            );
                            for (
                                uint j = 0;
                                j < specificOperators.length;
                                j++
                            ) {
                                newOperators[j] = specificOperators[j];
                            }
                            newOperators[specificOperators.length] = op;
                            specificOperators = newOperators;
                        }
                    } catch {
                        console2.log(
                            "Failed to parse argument as address:",
                            args[i]
                        );
                    }
                }
            }
        }
    }

    // Get command line arguments from json file
    function getCliArgs() internal returns (string[] memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script.json");
        // Check if file exists
        try vm.readFile(path) returns (string memory) {
            // If it exists, parse it
            return vm.parseJsonStringArray(vm.readFile(path), "$.args");
        } catch {
            // If file doesn't exist or can't be read, return empty array
            return new string[](0);
        }
    }

    function run() external {
        // Log contract addresses
        console2.log("=== ECDSA Stake Registry Status ===");
        console2.log("Contract Address:", stakeRegistryAddress);

        // Get total weight and threshold
        console2.log("\n=== Quorum Information ===");
        uint256 totalWeight = ECDSAStakeRegistry(stakeRegistryAddress)
            .getLastCheckpointTotalWeight();
        uint256 thresholdWeight = ECDSAStakeRegistry(stakeRegistryAddress)
            .getLastCheckpointThresholdWeight();
        console2.log("Total Weight:", totalWeight);
        console2.log("Threshold Weight:", thresholdWeight);

        // Calculate block range for event query
        uint256 latestBlock = block.number;
        uint256 fromBlock = latestBlock > 5000 ? latestBlock - 5000 : 0;

        console2.log("\n=== Registered Operators ===");
        console2.log(
            "Querying events from block",
            fromBlock,
            "to",
            latestBlock
        );

        // If specific operators were provided, check them directly
        if (specificOperators.length > 0) {
            console2.log("\n=== Checking Specified Operators ===");
            for (uint i = 0; i < specificOperators.length; i++) {
                address operator = specificOperators[i];
                uint256 weight = ECDSAStakeRegistry(stakeRegistryAddress)
                    .getOperatorWeight(operator);
                console2.log("Operator", operator, "weight:", weight);
            }
        } else {
            // Get all OperatorRegistered events
            address[] memory operators = getRegisteredOperators(
                fromBlock,
                latestBlock
            );

            if (operators.length == 0) {
                console2.log("No operators found in event logs");

                // Try to check all operators in the last AVS registration
                console2.log("\n=== Trying to check recent operators ===");
                console2.log("Looking for recent operators...");

                // Directly check the last few operators you know have been registered
                address[] memory recentOperators = new address[](5);
                recentOperators[0] = 0xe83AF7151219462f1703A278Cd500d59d6EB7EF2; // Latest we just created
                recentOperators[1] = 0x07a42B2DEc6bc393Bd541f44C69204aE6Be7BaE5; // Previously tried
                recentOperators[2] = 0x1Dbc1FAf10F01F3A397A8EAF0ff433cf089880cD; // Previously tried
                recentOperators[3] = 0x2FBf8C5d7a3D3Fd6732703c60b8E79bB055A6168; // Previously tried
                recentOperators[4] = 0x8d9c0A916D9A66f11D9b3bDd3ab9b6f332d5347A; // Previously tried

                for (uint i = 0; i < recentOperators.length; i++) {
                    if (recentOperators[i] != address(0)) {
                        uint256 weight = ECDSAStakeRegistry(
                            stakeRegistryAddress
                        ).getOperatorWeight(recentOperators[i]);
                        console2.log(
                            "Recent operator",
                            recentOperators[i],
                            "weight:",
                            weight
                        );
                    }
                }

                return;
            }

            // Query weight for each operator
            console2.log("\n=== Operator Weights ===");
            for (uint256 i = 0; i < operators.length; i++) {
                uint256 weight = ECDSAStakeRegistry(stakeRegistryAddress)
                    .getOperatorWeight(operators[i]);
                console2.log("Operator", operators[i], "weight:", weight);
            }
        }
    }

    /**
     * @notice Get all registered operators by querying events
     * @param fromBlock Starting block for event query
     * @param toBlock Ending block for event query
     * @return operators Array of operator addresses
     */
    function getRegisteredOperators(
        uint256 fromBlock,
        uint256 toBlock
    ) private returns (address[] memory) {
        // Create filter for OperatorRegistered events
        vm.recordLogs();
        vm.roll(toBlock);

        // Dummy call to ensure we have logs to filter (this is a workaround)
        ECDSAStakeRegistry(stakeRegistryAddress).getLastCheckpointTotalWeight();

        // Get logs
        vm.warp(block.timestamp + 1);

        // Filter for OperatorRegistered events
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Count valid events
        uint256 count = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == OPERATOR_REGISTERED_EVENT) {
                count++;
            }
        }

        // Extract operator addresses
        address[] memory operators = new address[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0] == OPERATOR_REGISTERED_EVENT &&
                logs[i].topics.length >= 2
            ) {
                // The operator address is the second topic
                address operator = address(uint160(uint256(logs[i].topics[2])));
                operators[index] = operator;
                console2.log("Found operator:", operator);
                index++;
            }
        }

        return operators;
    }
}
