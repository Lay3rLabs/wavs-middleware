// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {OperatorSet} from "@eigenlayer/contracts/libraries/OperatorSetLib.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {WavsServiceManager} from "src/eigenlayer/bls/WavsServiceManager.sol";

/**
 * @title WavsListOperators
 * @author Lay3rLabs
 * @notice This script lists the operators for the WAVS service manager.
 * @dev This script is used to list the operators for the WAVS service manager.
 */
contract WavsListOperators is Script {
    /**
     * @notice The operator info struct.
     * @param stakeRegistry The stake registry address.
     * @param totalWeight The total weight of the operators.
     * @param minimumStake The minimum stake of the operators.
     * @param operators The operators.
     * @param weights The weights of the operators.
     * @param strategies The strategies of the operators.
     */
    struct OperatorInfo {
        address stakeRegistry;
        uint96 totalWeight;
        uint96 minimumStake;
        address[] operators;
        uint96[] weights;
        IStakeRegistry.StrategyParams[] strategies;
    }

    /// @notice The environment variable for the WAVS service manager address.
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";

    WavsServiceManager private serviceManager;
    uint256 private _quorumNumerator;
    uint256 private _quorumDenominator;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        serviceManager = WavsServiceManager(vm.envAddress(ENV_SERVICE_MANAGER));
    }

    /// @notice The run function for the script.
    function run() external {
        vm.startBroadcast();
        OperatorInfo memory opInfo = _listOperators(serviceManager.getStakeRegistry());
        _quorumNumerator = serviceManager.quorumNumerator();
        _quorumDenominator = serviceManager.quorumDenominator();
        _writeOperatorListJson(opInfo);
        vm.stopBroadcast();

        console.log("=== List Operators ===");
        console.log("Service Manager Address:", address(serviceManager));
        console.log("Stake Registry Address:", serviceManager.getStakeRegistry());
        console.log("Strategies:");
        for (uint256 i = 0; i < opInfo.strategies.length; ++i) {
            console.log(
                string.concat(
                    "Strategy ",
                    Strings.toString(i),
                    ": ",
                    Strings.toHexString(uint160(address(opInfo.strategies[i].strategy)), 20),
                    " (",
                    Strings.toString(opInfo.strategies[i].multiplier),
                    ")"
                )
            );
        }

        console.log(" "); // Blank line for separation
        console.log("=== Quorum Information ===");
        console.log(string.concat("Total Weight: ", Strings.toString(uint256(opInfo.totalWeight))));
        console.log(
            string.concat("Minimum Stake: ", Strings.toString(uint256(opInfo.minimumStake)))
        );

        console.log(" "); // Blank line for separation
        console.log("=== Registered Operators ===");
        for (uint256 i = 0; i < opInfo.operators.length; ++i) {
            string memory op = string.concat(
                "Operator ",
                Strings.toString(i + 1),
                ": ",
                Strings.toHexString(uint160(opInfo.operators[i]), 20)
            );
            string memory weight = string.concat("= ", Strings.toString(uint256(opInfo.weights[i])));
            console.log(op, weight);
        }

        console.log(" "); // Blank line for separation
        console.log("=== Service Manager Quorum Information ===");
        console.log(string.concat("Quorum Numerator: ", Strings.toString(_quorumNumerator)));
        console.log(string.concat("Quorum Denominator: ", Strings.toString(_quorumDenominator)));
    }

    /**
     * @notice The list operators function.
     * @param _stakeRegistry The stake registry address.
     * @return opInfo The operator info.
     */
    function _listOperators(
        address _stakeRegistry
    ) private view returns (OperatorInfo memory) {
        IStakeRegistry stakeRegistry = IStakeRegistry(_stakeRegistry);

        uint96 totalWeight = stakeRegistry.getCurrentTotalStake(0);

        IAllocationManager allocationManager =
            IAllocationManager(serviceManager.getAllocationManager());
        OperatorSet memory opSetQuery = OperatorSet({avs: address(serviceManager), id: 0});
        address[] memory operators = allocationManager.getMembers(opSetQuery);

        uint96[] memory weights = new uint96[](operators.length);
        for (uint256 i = 0; i < operators.length; ++i) {
            weights[i] = stakeRegistry.weightOfOperatorForQuorum(0, operators[i]);
        }

        uint256 strategyParamsLength = stakeRegistry.strategyParamsLength(0);
        IStakeRegistry.StrategyParams[] memory strategies =
            new IStakeRegistry.StrategyParams[](strategyParamsLength);
        for (uint256 i = 0; i < strategyParamsLength; ++i) {
            strategies[i] = stakeRegistry.strategyParamsByIndex(uint8(0), i);
        }

        return OperatorInfo({
            stakeRegistry: address(stakeRegistry),
            totalWeight: totalWeight,
            minimumStake: stakeRegistry.minimumStakeForQuorum(0),
            operators: operators,
            weights: weights,
            strategies: strategies
        });
    }

    /**
     * @notice The write operator list JSON function.
     * @param opInfo The operator info.
     */
    function _writeOperatorListJson(
        OperatorInfo memory opInfo
    ) internal {
        if (!vm.exists("deployments/wavs-bls")) {
            vm.createDir("deployments/wavs-bls", true);
        }

        string memory json = "{\"serviceManager\":\"";
        json = string.concat(json, Strings.toHexString(uint160(address(serviceManager)), 20));
        json = string.concat(json, "\",\"stakeRegistry\":\"");
        json = string.concat(json, Strings.toHexString(uint160(opInfo.stakeRegistry), 20));
        json = string.concat(json, "\",\"totalWeight\":\"");
        json = string.concat(json, Strings.toString(opInfo.totalWeight));
        json = string.concat(json, "\",\"minimumStake\":\"");
        json = string.concat(json, Strings.toString(opInfo.minimumStake));
        json = string.concat(json, "\",\"strategies\":[");

        for (uint256 i = 0; i < opInfo.strategies.length; ++i) {
            if (i > 0) {
                json = string.concat(json, ",");
            }
            json = string.concat(json, "{\"strategy\":\"");
            json = string.concat(
                json, Strings.toHexString(uint160(address(opInfo.strategies[i].strategy)), 20)
            );
            json = string.concat(json, "\",\"multiplier\":\"");
            json = string.concat(json, Strings.toString(opInfo.strategies[i].multiplier));
            json = string.concat(json, "\"}");
        }

        json = string.concat(json, "],\"operators\":[");

        for (uint256 i = 0; i < opInfo.operators.length; ++i) {
            if (i > 0) {
                json = string.concat(json, ",");
            }
            json = string.concat(json, "{\"operator\":\"");
            json = string.concat(json, Strings.toHexString(uint160(opInfo.operators[i]), 20));
            json = string.concat(json, "\",\"weight\":\"");
            json = string.concat(json, Strings.toString(opInfo.weights[i]));
            json = string.concat(json, "\"}");
        }

        json = string.concat(json, "],\"quorumNumerator\":\"");
        json = string.concat(json, Strings.toString(_quorumNumerator));
        json = string.concat(json, "\",\"quorumDenominator\":\"");
        json = string.concat(json, Strings.toString(_quorumDenominator));
        json = string.concat(json, "\"");
        json = string.concat(json, "}");

        vm.writeFile("deployments/wavs-bls/list_operators.json", json);
    }
}
