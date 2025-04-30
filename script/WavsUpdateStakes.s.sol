// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ECDSAStakeRegistry} from "lib/eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";

/**
 * @title WavsUpdateStakes
 * @notice A Forge script to update operator stakes in the stake registry
 */
contract WavsUpdateStakes is Script {
    using Strings for *;

    // Deployment file path
    string private deploymentPath;

    // Contract addresses
    address private stakeRegistryAddress;

    // Operators to update
    address[] private operators;

    // Deployer key for transactions
    uint256 private deployerPrivateKey;
    address private deployerAddress;

    function setUp() public {
        // Get deployer key
        deployerPrivateKey = vm.envOr("FUNDED_KEY", uint256(0));
        if (deployerPrivateKey == 0) {
            revert("FUNDED_KEY environment variable is required");
        }
        deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("Deployer address:", deployerAddress);

        // Try to find deployments file in multiple locations
        string[] memory paths = new string[](3);
        paths[0] = string.concat(
            vm.projectRoot(),
            "/deployments/wavs-middleware/",
            vm.toString(block.chainid),
            ".json"
        );
        paths[1] = "/root/.nodes/avs_deploy.json";
        paths[2] = string.concat(
            vm.projectRoot(),
            "/../.nodes/avs_deploy.json"
        );

        bool found = false;
        for (uint i = 0; i < paths.length; i++) {
            if (vm.exists(paths[i])) {
                deploymentPath = paths[i];
                found = true;
                break;
            }
        }

        if (!found) {
            revert("Deployment file not found");
        }
        console2.log("Using deployment file:", deploymentPath);

        // Get stake registry address
        string memory json = vm.readFile(deploymentPath);
        stakeRegistryAddress = vm.parseJsonAddress(
            json,
            ".addresses.stakeRegistry"
        );
        if (stakeRegistryAddress == address(0)) {
            revert("Invalid stake registry address");
        }
        console2.log("Stake Registry:", stakeRegistryAddress);

        // Parse CLI args for operators
        string memory operatorsEnv = vm.envOr("OPERATORS", string(""));
        if (bytes(operatorsEnv).length == 0) {
            // No operators specified, show error
            revert(
                "No operators specified. Please provide operators using the OPERATORS environment variable."
            );
        } else {
            // Use operators from environment variable (comma-separated list)
            console2.log("Using operators from environment:", operatorsEnv);

            // Parse operator addresses manually (no split function in Solidity)
            // Count commas to determine number of operators
            uint commaCount = 0;
            for (uint i = 0; i < bytes(operatorsEnv).length; i++) {
                if (bytes(operatorsEnv)[i] == bytes(",")[0]) {
                    commaCount++;
                }
            }

            // Create array with the right size
            operators = new address[](commaCount + 1);

            // Parse each address
            uint currentIndex = 0;
            uint lastCommaPos = 0;

            // Handle the case where there are no commas
            if (commaCount == 0) {
                operators[0] = vm.parseAddress(operatorsEnv);
                console2.log("Operator 0:", operators[0]);
            } else {
                // Handle multiple operators separated by commas
                for (uint i = 0; i < bytes(operatorsEnv).length; i++) {
                    if (
                        bytes(operatorsEnv)[i] == bytes(",")[0] ||
                        i == bytes(operatorsEnv).length - 1
                    ) {
                        uint endPos = i;
                        if (i == bytes(operatorsEnv).length - 1) {
                            endPos = i + 1;
                        }

                        // Extract substring
                        string memory addressStr = substring(
                            operatorsEnv,
                            lastCommaPos,
                            endPos
                        );

                        // Remove leading/trailing spaces
                        addressStr = trim(addressStr);

                        // Parse if not empty
                        if (bytes(addressStr).length > 0) {
                            operators[currentIndex] = vm.parseAddress(
                                addressStr
                            );
                            console2.log(
                                "Operator",
                                currentIndex,
                                ":",
                                operators[currentIndex]
                            );
                            currentIndex++;
                        }

                        lastCommaPos = i + 1;
                    }
                }
            }
        }
    }

    function run() external {
        // Check total weight before
        uint256 totalWeightBefore = ECDSAStakeRegistry(stakeRegistryAddress)
            .getLastCheckpointTotalWeight();
        console2.log("Total weight before:", totalWeightBefore);

        // For each operator, check weight before
        for (uint i = 0; i < operators.length; i++) {
            uint256 weightBefore = ECDSAStakeRegistry(stakeRegistryAddress)
                .getOperatorWeight(operators[i]);
            console2.log(
                "Operator",
                operators[i],
                "weight before:",
                weightBefore
            );
        }

        // Update stakes
        console2.log("Updating stakes for", operators.length, "operators");
        vm.startBroadcast(deployerPrivateKey);
        ECDSAStakeRegistry(stakeRegistryAddress).updateOperators(operators);
        vm.stopBroadcast();

        // Check total weight after
        uint256 totalWeightAfter = ECDSAStakeRegistry(stakeRegistryAddress)
            .getLastCheckpointTotalWeight();
        console2.log("Total weight after:", totalWeightAfter);

        // For each operator, check weight after
        for (uint i = 0; i < operators.length; i++) {
            uint256 weightAfter = ECDSAStakeRegistry(stakeRegistryAddress)
                .getOperatorWeight(operators[i]);
            console2.log(
                "Operator",
                operators[i],
                "weight after:",
                weightAfter
            );
        }

        console2.log("Stakes updated successfully");
    }

    /**
     * @dev Extract a substring from a string
     * @param str The input string
     * @param startIndex The start index (inclusive)
     * @param endIndex The end index (exclusive)
     * @return The extracted substring
     */
    function substring(
        string memory str,
        uint startIndex,
        uint endIndex
    ) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);

        if (endIndex > strBytes.length) {
            endIndex = strBytes.length;
        }
        if (startIndex >= endIndex) {
            return "";
        }

        bytes memory result = new bytes(endIndex - startIndex);
        for (uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }

        return string(result);
    }

    /**
     * @dev Remove leading and trailing spaces from a string
     * @param str The input string
     * @return The trimmed string
     */
    function trim(string memory str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        if (strBytes.length == 0) {
            return "";
        }

        uint startIndex = 0;
        uint endIndex = strBytes.length;

        // Find the first non-space character
        while (startIndex < endIndex && strBytes[startIndex] == " ") {
            startIndex++;
        }

        // Find the last non-space character
        while (endIndex > startIndex && strBytes[endIndex - 1] == " ") {
            endIndex--;
        }

        // Extract the trimmed substring
        return substring(str, startIndex, endIndex);
    }
}
