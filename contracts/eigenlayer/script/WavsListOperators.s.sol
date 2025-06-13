// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {WavsServiceManager} from "../src/WavsServiceManager.sol";
import {IAllocationManagerTypes, IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {OperatorSet} from "@eigenlayer/contracts/libraries/OperatorSetLib.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract WavsListOperators is Script {

    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";

    struct OperatorInfo {
        address stakeRegistry;
        uint256 totalWeight;
        uint256 thresholdWeight;
        address[] operators;
        address[] signingKeys;
        uint256[] weights;
    }

    // configuration
    address private serviceManagerAddr;

    function setUp() public virtual {
        serviceManagerAddr = vm.envAddress(ENV_SERVICE_MANAGER);
    }

    function run() external {
        vm.startBroadcast();
        OperatorInfo memory opInfo = listOperators(serviceManagerAddr);
        vm.stopBroadcast();

        console.log("=== List Operators ===");
        console.log("Service Manager Address:", serviceManagerAddr);
        console.log("Stake Registry Address:", address(opInfo.stakeRegistry));

        console.log(" "); // Blank line for separation
        console.log("=== Quorum Information ===");
        string memory total = string.concat("Total Weight: ", Strings.toString(opInfo.totalWeight));
        string memory threshold = string.concat("Threshold Weight: ", Strings.toString(opInfo.thresholdWeight));
        console.log(total);
        console.log(threshold);
        // FIXME: should be easier, but the following has no output
        // console.log("Total Weight: %d", opInfo.totalWeight);
        // console.log("Threshold Weight: %d", opInfo.thresholdWeight);

        console.log(" "); // Blank line for separation
        console.log("=== Registered Operators ===");
        for (uint256 i = 0; i < opInfo.operators.length; i++) {
            string memory op = string.concat("Operator ", Strings.toString(i + 1), ": ", Strings.toHexString(uint160(opInfo.operators[i]), 20));
            string memory sign = string.concat("-> ", Strings.toHexString(uint160(opInfo.signingKeys[i]), 20));
            string memory weight = string.concat("= ", Strings.toString(opInfo.weights[i]));
            console.log(op, sign, weight);
        }
    }

    function listOperators(address serviceManagerAddress) internal returns (OperatorInfo memory) {
        WavsServiceManager serviceManager = WavsServiceManager(serviceManagerAddress);
        ECDSAStakeRegistry stakeRegistry = ECDSAStakeRegistry(serviceManager.stakeRegistry());

        uint256 totalWeight = stakeRegistry.getLastCheckpointTotalWeight();
        uint256 thresholdWeight = stakeRegistry.getLastCheckpointThresholdWeight();

        IAllocationManager allocationManager = IAllocationManager(serviceManager.allocationManager());
        OperatorSet memory opSetQuery = OperatorSet({
            avs: serviceManagerAddress, 
            id: 1
        });
        address[] memory operators = allocationManager.getMembers(opSetQuery);

        uint256[] memory weights = new uint256[](operators.length);
        for (uint256 i = 0; i < operators.length; i++) {
            weights[i] = stakeRegistry.getOperatorWeight(operators[i]);
        }

        address[] memory signingKeys = new address[](operators.length);
        for (uint256 i = 0; i < operators.length; i++) {
            signingKeys[i] = stakeRegistry.getLatestOperatorSigningKey(operators[i]);
        }

        return OperatorInfo({
            stakeRegistry: address(stakeRegistry),
            totalWeight: totalWeight,
            thresholdWeight: thresholdWeight,
            operators: operators,
            signingKeys: signingKeys,
            weights: weights
        });
    }
    
}
