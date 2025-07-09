// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {OperatorSet} from "@eigenlayer/contracts/libraries/OperatorSetLib.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {WavsServiceManager} from "src/eigenlayer/ecdsa/WavsServiceManager.sol";

/// @title WavsMirrorListOperators
/// @notice Script to list operators and their weights from both source and mirror chains
/// @dev This script reads operator information from the source chain and their corresponding weights from the mirror chain
contract WavsMirrorListOperators is Script {
    // Environment variable names
    string public constant ENV_SOURCE_SERVICE_MANAGER = "SOURCE_SERVICE_MANAGER_ADDRESS";
    string public constant ENV_MIRROR_SERVICE_MANAGER = "MIRROR_SERVICE_MANAGER_ADDRESS";
    string public constant SOURCE_RPC_URL = "SOURCE_RPC_URL";
    string public constant MIRROR_RPC_URL = "MIRROR_RPC_URL";

    /// @notice Structure to hold operator information
    struct OperatorInfo {
        address stakeRegistry;
        uint256 totalWeight;
        uint256 thresholdWeight;
        address[] operators;
        address[] signingKeyAddresses;
        uint256[] weights;
    }

    // Configuration variables
    address private sourceServiceManagerAddr;
    address private mirrorServiceManagerAddr;
    string private sourceRpcUrl;
    string private mirrorRpcUrl;

    error WavsMirrorListOperators__InvalidSourceServiceManagerAddress();
    error WavsMirrorListOperators__InvalidMirrorServiceManagerAddress();

    /// @notice Set up the script by reading environment variables
    /// @dev This function is called before run() and validates all required environment variables
    function setUp() public virtual {
        // Read and validate service manager addresses
        sourceServiceManagerAddr = vm.envAddress(ENV_SOURCE_SERVICE_MANAGER);
        mirrorServiceManagerAddr = vm.envAddress(ENV_MIRROR_SERVICE_MANAGER);

        // Read and validate RPC URLs
        sourceRpcUrl = vm.envString(SOURCE_RPC_URL);
        mirrorRpcUrl = vm.envString(MIRROR_RPC_URL);

        // Validate addresses
        if (sourceServiceManagerAddr == address(0)) {
            revert WavsMirrorListOperators__InvalidSourceServiceManagerAddress();
        }
        if (mirrorServiceManagerAddr == address(0)) {
            revert WavsMirrorListOperators__InvalidMirrorServiceManagerAddress();
        }
    }

    /// @notice Main function to run the script
    /// @dev This function orchestrates the process of fetching and displaying operator information
    function run() external {
        // Get operator information
        OperatorInfo memory opInfo =
            listOperators(sourceServiceManagerAddr, mirrorServiceManagerAddr);
        uint256 quorumNumerator = WavsServiceManager(mirrorServiceManagerAddr).quorumNumerator();
        uint256 quorumDenominator = WavsServiceManager(mirrorServiceManagerAddr).quorumDenominator();

        // Display results
        displayResults(opInfo, quorumNumerator, quorumDenominator);
    }

    /// @notice Internal function to fetch operator information from both chains
    /// @param sourceServiceManagerAddress The address of the source chain service manager
    /// @param mirrorServiceManagerAddress The address of the mirror chain service manager
    /// @return OperatorInfo struct containing all operator-related information
    function listOperators(
        address sourceServiceManagerAddress,
        address mirrorServiceManagerAddress
    ) internal returns (OperatorInfo memory) {
        // Create source chain fork and get operators
        vm.createSelectFork(sourceRpcUrl);
        WavsServiceManager sourceServiceManager = WavsServiceManager(sourceServiceManagerAddress);

        IAllocationManager allocationManager =
            IAllocationManager(sourceServiceManager.allocationManager());
        OperatorSet memory opSetQuery = OperatorSet({avs: sourceServiceManagerAddress, id: 1});
        address[] memory operators = allocationManager.getMembers(opSetQuery);

        // Create mirror chain fork and get stake information
        vm.createSelectFork(mirrorRpcUrl);
        WavsServiceManager mirrorServiceManager = WavsServiceManager(mirrorServiceManagerAddress);
        ECDSAStakeRegistry mirrorStakeRegistry =
            ECDSAStakeRegistry(mirrorServiceManager.stakeRegistry());

        // Get quorum information
        uint256 totalWeight = mirrorStakeRegistry.getLastCheckpointTotalWeight();
        uint256 thresholdWeight = mirrorStakeRegistry.getLastCheckpointThresholdWeight();

        // Get operator weights and signing keys
        uint256[] memory weights = new uint256[](operators.length);
        address[] memory signingKeyAddresses = new address[](operators.length);

        for (uint256 i = 0; i < operators.length; i++) {
            weights[i] = mirrorStakeRegistry.getOperatorWeight(operators[i]);
            signingKeyAddresses[i] = mirrorStakeRegistry.getLatestOperatorSigningKey(operators[i]);
        }

        writeOperatorListJson(
            block.chainid,
            OperatorInfo({
                stakeRegistry: address(mirrorStakeRegistry),
                totalWeight: totalWeight,
                thresholdWeight: thresholdWeight,
                operators: operators,
                signingKeyAddresses: signingKeyAddresses,
                weights: weights
            })
        );

        return OperatorInfo({
            stakeRegistry: address(mirrorStakeRegistry),
            totalWeight: totalWeight,
            thresholdWeight: thresholdWeight,
            operators: operators,
            signingKeyAddresses: signingKeyAddresses,
            weights: weights
        });
    }

    /// @notice Internal function to display the results in a formatted way
    /// @param opInfo The operator information to display
    function displayResults(
        OperatorInfo memory opInfo,
        uint256 quorumNumerator,
        uint256 quorumDenominator
    ) internal view {
        console.log("=== List Operators ===");
        console.log("Source Service Manager Address:", sourceServiceManagerAddr);
        console.log("Mirror Service Manager Address:", mirrorServiceManagerAddr);
        console.log("Mirror Stake Registry Address:", address(opInfo.stakeRegistry));

        console.log(" "); // Blank line for separation
        console.log("=== Quorum Information ===");
        string memory total = string.concat("Total Weight: ", Strings.toString(opInfo.totalWeight));
        string memory threshold =
            string.concat("Threshold Weight: ", Strings.toString(opInfo.thresholdWeight));
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
                "-> ", Strings.toHexString(uint160(opInfo.signingKeyAddresses[i]), 20)
            );
            string memory weight = string.concat("= ", Strings.toString(opInfo.weights[i]));
            console.log(op, sign, weight);
        }

        console.log(" "); // Blank line for separation
        console.log("=== Mirror Service Manager Quorum Information ===");
        string memory quorum = string.concat(
            "Quorum: ", Strings.toString(quorumNumerator), "/", Strings.toString(quorumDenominator)
        );
        console.log(quorum);
    }

    function writeOperatorListJson(uint256 chainId, OperatorInfo memory opInfo) internal {
        string memory fileName =
            string.concat("deployments/wavs-mirror/list-operators-", vm.toString(chainId), ".json");
        if (!vm.exists("deployments/wavs-mirror")) {
            vm.createDir("deployments/wavs-mirror", true);
        }

        string memory json = string.concat(
            "{",
            "\"sourceServiceManager\":\"",
            Strings.toHexString(uint160(sourceServiceManagerAddr)),
            "\",",
            "\"mirrorServiceManager\":\"",
            Strings.toHexString(uint160(mirrorServiceManagerAddr)),
            "\",",
            "\"stakeRegistry\":\"",
            Strings.toHexString(uint160(address(opInfo.stakeRegistry))),
            "\",",
            "\"totalWeight\":\"",
            Strings.toString(opInfo.totalWeight),
            "\",",
            "\"thresholdWeight\":\"",
            Strings.toString(opInfo.thresholdWeight),
            "\",",
            "\"operators\":["
        );

        for (uint256 i = 0; i < opInfo.operators.length; i++) {
            if (i > 0) {
                json = string.concat(json, ",");
            }
            json = string.concat(
                json,
                "{",
                "\"operator\":\"",
                Strings.toHexString(uint160(opInfo.operators[i]), 20),
                "\",",
                "\"signingKeyAddress\":\"",
                Strings.toHexString(uint160(opInfo.signingKeyAddresses[i]), 20),
                "\",",
                "\"weight\":\"",
                Strings.toString(opInfo.weights[i]),
                "\"",
                "}"
            );
        }

        json = string.concat(json, "]}");
        vm.writeFile(fileName, json);
        console.log("Operator list written to:", fileName);
    }
}
