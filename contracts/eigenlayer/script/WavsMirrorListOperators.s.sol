// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {WavsServiceManager} from "../src/WavsServiceManager.sol";
import {IAllocationManagerTypes, IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {OperatorSet} from "@eigenlayer/contracts/libraries/OperatorSetLib.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title WavsMirrorListOperators
/// @notice Script to list operators and their weights from both source and mirror chains
/// @dev This script reads operator information from the source chain and their corresponding weights from the mirror chain
contract WavsMirrorListOperators is Script {
    // Environment variable names
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";
    string public constant ENV_MIRROR_SERVICE_MANAGER = "MIRROR_SERVICE_MANAGER_ADDRESS";
    string public constant SOURCE_RPC_URL = "SOURCE_RPC_URL";
    string public constant MIRROR_RPC_URL = "MIRROR_RPC_URL";

    /// @notice Structure to hold operator information
    struct OperatorInfo {
        address stakeRegistry;
        uint256 totalWeight;
        uint256 thresholdWeight;
        address[] operators;
        address[] signingKeys;
        uint256[] weights;
    }

    // Configuration variables
    address private serviceManagerAddr;
    address private mirrorServiceManagerAddr;
    string private sourceRpcUrl;
    string private mirrorRpcUrl;

    /// @notice Set up the script by reading environment variables
    /// @dev This function is called before run() and validates all required environment variables
    function setUp() public virtual {
        // Read and validate service manager addresses
        serviceManagerAddr = vm.envAddress(ENV_SERVICE_MANAGER);
        mirrorServiceManagerAddr = vm.envAddress(ENV_MIRROR_SERVICE_MANAGER);
        
        // Read and validate RPC URLs
        sourceRpcUrl = vm.envString(SOURCE_RPC_URL);
        mirrorRpcUrl = vm.envString(MIRROR_RPC_URL);

        // Validate addresses
        require(serviceManagerAddr != address(0), "Invalid service manager address");
        require(mirrorServiceManagerAddr != address(0), "Invalid mirror service manager address");
    }

    /// @notice Main function to run the script
    /// @dev This function orchestrates the process of fetching and displaying operator information
    function run() external {
        // Get operator information
        OperatorInfo memory opInfo = listOperators(serviceManagerAddr, mirrorServiceManagerAddr);

        // Display results
        displayResults(opInfo);
    }

    /// @notice Internal function to fetch operator information from both chains
    /// @param serviceManagerAddress The address of the source chain service manager
    /// @param mirrorServiceManagerAddress The address of the mirror chain service manager
    /// @return OperatorInfo struct containing all operator-related information
    function listOperators(
        address serviceManagerAddress,
        address mirrorServiceManagerAddress
    ) internal returns (OperatorInfo memory) {
        // Create source chain fork and get operators
        vm.createSelectFork(sourceRpcUrl);
        WavsServiceManager serviceManager = WavsServiceManager(serviceManagerAddress);

        IAllocationManager allocationManager = IAllocationManager(serviceManager.allocationManager());
        OperatorSet memory opSetQuery = OperatorSet({
            avs: serviceManagerAddress, 
            id: 1
        });
        address[] memory operators = allocationManager.getMembers(opSetQuery);

        // Create mirror chain fork and get stake information
        vm.createSelectFork(mirrorRpcUrl);
        WavsServiceManager mirrorServiceManager = WavsServiceManager(mirrorServiceManagerAddress);
        ECDSAStakeRegistry mirrorStakeRegistry = ECDSAStakeRegistry(mirrorServiceManager.stakeRegistry());

        // Get quorum information
        uint256 totalWeight = mirrorStakeRegistry.getLastCheckpointTotalWeight();
        uint256 thresholdWeight = mirrorStakeRegistry.getLastCheckpointThresholdWeight();

        // Get operator weights and signing keys
        uint256[] memory weights = new uint256[](operators.length);
        address[] memory signingKeys = new address[](operators.length);
        
        for (uint256 i = 0; i < operators.length; i++) {
            weights[i] = mirrorStakeRegistry.getOperatorWeight(operators[i]);
            signingKeys[i] = mirrorStakeRegistry.getLatestOperatorSigningKey(operators[i]);
        }

        return OperatorInfo({
            stakeRegistry: address(mirrorStakeRegistry),
            totalWeight: totalWeight,
            thresholdWeight: thresholdWeight,
            operators: operators,
            signingKeys: signingKeys,
            weights: weights
        });
    }

    /// @notice Internal function to display the results in a formatted way
    /// @param opInfo The operator information to display
    function displayResults(OperatorInfo memory opInfo) internal view {
        console.log("=== List Operators ===");
        console.log("Mirror Service Manager Address:", mirrorServiceManagerAddr);
        console.log("Mirror Stake Registry Address:", address(opInfo.stakeRegistry));

        console.log(" "); // Blank line for separation
        console.log("=== Quorum Information ===");
        string memory total = string.concat("Total Weight: ", Strings.toString(opInfo.totalWeight));
        string memory threshold = string.concat("Threshold Weight: ", Strings.toString(opInfo.thresholdWeight));
        console.log(total);
        console.log(threshold);

        console.log(" "); // Blank line for separation
        console.log("=== Registered Operators ===");
        for (uint256 i = 0; i < opInfo.operators.length; i++) {
            string memory op = string.concat(
                "Operator ", 
                Strings.toString(i + 1), 
                ": ", 
                Strings.toHexString(uint160(opInfo.operators[i]), 20)
            );
            string memory sign = string.concat(
                "-> ", 
                Strings.toHexString(uint160(opInfo.signingKeys[i]), 20)
            );
            string memory weight = string.concat(
                "= ", 
                Strings.toString(opInfo.weights[i])
            );
            console.log(op, sign, weight);
        }
    }
}
