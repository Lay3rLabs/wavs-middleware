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
        uint256 fromBlock = latestBlock > 2000 ? latestBlock - 2000 : 0;

        console2.log("\n=== Registered Operators ===");
        console2.log(
            "Querying events from block",
            fromBlock,
            "to",
            latestBlock
        );

        // Get all OperatorRegistered events
        address[] memory operators = getRegisteredOperators(
            fromBlock,
            latestBlock
        );

        if (operators.length == 0) {
            console2.log("No operators found");
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
