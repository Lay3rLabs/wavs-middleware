// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IECDSAStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {OperatorSet} from "@eigenlayer/contracts/libraries/OperatorSetLib.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {WavsServiceManager} from "src/eigenlayer/ecdsa/WavsServiceManager.sol";

/**
 * @title WavsListOperators
 * @author Lay3rLabs
 * @notice This script lists the operators for the WavsServiceManager contract.
 * @dev This script is used to list the operators for the WavsServiceManager contract.
 */
contract WavsListOperators is Script {
    /**
     * @notice The operator info struct.
     * @param stakeRegistry The stake registry address.
     * @param totalWeight The total weight.
     * @param thresholdWeight The threshold weight.
     * @param operators The operators.
     * @param signingKeyAddresses The signing key addresses.
     * @param weights The weights.
     */
    struct OperatorInfo {
        address stakeRegistry;
        uint256 totalWeight;
        uint256 thresholdWeight;
        address[] operators;
        address[] signingKeyAddresses;
        uint256[] weights;
    }

    /// @notice The environment variable for the WAVS service manager address.
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";

    WavsServiceManager private serviceManager;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        serviceManager = WavsServiceManager(vm.envAddress(ENV_SERVICE_MANAGER));
    }

    /// @notice The run function for the script.
    function run() external {
        OperatorInfo memory opInfo = listOperators();
        uint256 quorumNumerator = serviceManager.quorumNumerator();
        uint256 quorumDenominator = serviceManager.quorumDenominator();
        _writeOperatorListJson(opInfo);

        console.log("=== List Operators ===");
        console.log("Service Manager Address:", address(serviceManager));
        console.log("Stake Registry Address:", address(opInfo.stakeRegistry));

        console.log(" "); // Blank line for separation
        console.log("=== Quorum Information ===");
        string memory total = string.concat("Total Weight: ", Strings.toString(opInfo.totalWeight));
        string memory threshold =
            string.concat("Threshold Weight: ", Strings.toString(opInfo.thresholdWeight));
        console.log(total);
        console.log(threshold);
        // FIXME: should be easier, but the following has no output
        // console.log("Total Weight: %d", opInfo.totalWeight);
        // console.log("Threshold Weight: %d", opInfo.thresholdWeight);

        console.log(" "); // Blank line for separation
        console.log("=== Registered Operators ===");
        for (uint256 i = 0; i < opInfo.operators.length; ++i) {
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
        console.log("=== Service Manager Quorum Information ===");
        console.log(string.concat("Quorum Numerator: ", Strings.toString(quorumNumerator)));
        console.log(string.concat("Quorum Denominator: ", Strings.toString(quorumDenominator)));
    }

    /**
     * @notice The list operators function.
     * @return OperatorInfo struct containing all operator-related information
     */
    function listOperators() private view returns (OperatorInfo memory) {
        IECDSAStakeRegistry stakeRegistry = IECDSAStakeRegistry(serviceManager.stakeRegistry());

        uint256 totalWeight = stakeRegistry.getLastCheckpointTotalWeight();
        uint256 thresholdWeight = stakeRegistry.getLastCheckpointThresholdWeight();

        IAllocationManager allocationManager =
            IAllocationManager(serviceManager.getAllocationManager());
        OperatorSet memory opSetQuery = OperatorSet({avs: address(serviceManager), id: 0});
        address[] memory operators = allocationManager.getMembers(opSetQuery);

        uint256[] memory weights = new uint256[](operators.length);
        for (uint256 i = 0; i < operators.length; ++i) {
            weights[i] = stakeRegistry.getOperatorWeight(operators[i]);
        }

        address[] memory signingKeyAddresses = new address[](operators.length);
        for (uint256 i = 0; i < operators.length; ++i) {
            signingKeyAddresses[i] = stakeRegistry.getLatestOperatorSigningKey(operators[i]);
        }

        return OperatorInfo({
            stakeRegistry: address(stakeRegistry),
            totalWeight: totalWeight,
            thresholdWeight: thresholdWeight,
            operators: operators,
            signingKeyAddresses: signingKeyAddresses,
            weights: weights
        });
    }

    /**
     * @notice The write operator list JSON function.
     * @param opInfo The operator info.
     */
    function _writeOperatorListJson(
        OperatorInfo memory opInfo
    ) private {
        if (!vm.exists("deployments/wavs-ecdsa")) {
            vm.createDir("deployments/wavs-ecdsa", true);
        }

        string memory json = string.concat("{");
        json = string.concat(json, "\"stakeRegistry\":\"");
        json = string.concat(json, Strings.toHexString(uint160(address(opInfo.stakeRegistry)), 20));
        json = string.concat(json, "\",\"totalWeight\":\"");
        json = string.concat(json, Strings.toString(opInfo.totalWeight));
        json = string.concat(json, "\",\"thresholdWeight\":\"");
        json = string.concat(json, Strings.toString(opInfo.thresholdWeight));
        json = string.concat(json, "\",\"operators\":[");
        for (uint256 i = 0; i < opInfo.operators.length; ++i) {
            json = string.concat(json, "{\"operator\":\"");
            json = string.concat(json, Strings.toHexString(uint160(opInfo.operators[i]), 20));
            json = string.concat(json, "\",\"signingKeyAddress\":\"");
            json =
                string.concat(json, Strings.toHexString(uint160(opInfo.signingKeyAddresses[i]), 20));
            json = string.concat(json, "\",\"weight\":\"");
            json = string.concat(json, Strings.toString(opInfo.weights[i]));
            json = string.concat(json, "\"}");
            if (i < opInfo.operators.length - 1) {
                json = string.concat(json, ",");
            }
        }
        json = string.concat(json, "]");
        json = string.concat(json, "}");

        vm.writeFile("deployments/wavs-ecdsa/list_operators.json", json);
    }
}
