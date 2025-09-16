// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Vm} from "forge-std/Vm.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";
import {ISlashingRegistryCoordinator} from
    "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {
    IStakeRegistry,
    IStakeRegistryTypes
} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {ISocketRegistry} from "@eigenlayer-middleware/src/interfaces/ISocketRegistry.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {OperatorSet} from "@eigenlayer/contracts/libraries/OperatorSetLib.sol";
import {IStrategy} from "@eigenlayer/contracts/interfaces/IStrategy.sol";
import {WavsServiceManager} from "src/eigenlayer/bls/WavsServiceManager.sol";

/**
 * @title WavsListOperatorsLib
 * @author Lay3rLabs
 * @notice This library contains the functions for listing the operators for the WAVS service manager.
 * @dev This library is used to list the operators for the WAVS service manager.
 */
library WavsListOperatorsLib {
    /* solhint-disable gas-struct-packing */
    /**
     * @notice The operator data struct.
     * @param operator The operator address.
     * @param operatorId The operator ID.
     * @param pubkey The public key.
     * @param pubkeyG2 The G2 public key.
     * @param socket The socket information.
     * @param stake The stake amount.
     */
    struct OperatorData {
        address operator;
        bytes32 operatorId;
        BN254.G1Point pubkey;
        BN254.G2Point pubkeyG2;
        string socket;
        uint96 stake;
    }
    /* solhint-enable gas-struct-packing */

    /**
     * @notice The config data struct.
     * @param totalWeight The total weight.
     * @param minimumStake The minimum stake.
     * @param strategies The strategy parameters.
     * @param operators The operator data.
     * @param quorumNumerator The quorum numerator.
     * @param quorumDenominator The quorum denominator.
     */
    struct ConfigData {
        uint96 totalWeight;
        uint96 minimumStake;
        IStakeRegistry.StrategyParams[] strategies;
        OperatorData[] operators;
        uint256 quorumNumerator;
        uint256 quorumDenominator;
    }

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice The error for the config file not found.
    error WavsListOperatorsLib__ConfigFileNotFound();

    /**
     * @notice The get config data function.
     * @param _serviceManager The service manager address.
     * @param _quorumNumber The quorum number.
     * @param _operators The operators.
     * @return configData The config data.
     */
    function getConfigData(
        address _serviceManager,
        uint8 _quorumNumber,
        address[] memory _operators
    ) internal view returns (ConfigData memory configData) {
        WavsServiceManager serviceManager = WavsServiceManager(_serviceManager);
        configData.quorumNumerator = serviceManager.quorumNumerator();
        configData.quorumDenominator = serviceManager.quorumDenominator();

        ISlashingRegistryCoordinator slashingRegistryCoordinator =
            ISlashingRegistryCoordinator(serviceManager.getRegistryCoordinator());
        IStakeRegistry stakeRegistry = slashingRegistryCoordinator.stakeRegistry();
        ISocketRegistry socketRegistry = slashingRegistryCoordinator.socketRegistry();
        IBLSApkRegistry blsApkRegistry = slashingRegistryCoordinator.blsApkRegistry();

        configData.totalWeight = stakeRegistry.getCurrentTotalStake(_quorumNumber);
        configData.minimumStake = stakeRegistry.minimumStakeForQuorum(_quorumNumber);

        uint256 operatorCount = _operators.length;

        OperatorData[] memory operatorData = new OperatorData[](operatorCount);

        for (uint256 i = 0; i < operatorCount; ++i) {
            (BN254.G1Point memory pubkey, bytes32 operatorId) =
                blsApkRegistry.getRegisteredPubkey(_operators[i]);
            operatorData[i] = OperatorData({
                operator: _operators[i],
                operatorId: operatorId,
                pubkey: pubkey,
                pubkeyG2: blsApkRegistry.getOperatorPubkeyG2(_operators[i]),
                socket: socketRegistry.getOperatorSocket(operatorId),
                stake: stakeRegistry.getCurrentStake(operatorId, _quorumNumber)
            });
        }

        uint256 strategyParamsLength = stakeRegistry.strategyParamsLength(_quorumNumber);
        IStakeRegistry.StrategyParams[] memory strategies =
            new IStakeRegistry.StrategyParams[](strategyParamsLength);
        for (uint256 i = 0; i < strategyParamsLength; ++i) {
            strategies[i] = stakeRegistry.strategyParamsByIndex(_quorumNumber, i);
        }

        configData.strategies = strategies;
        configData.operators = operatorData;

        return configData;
    }

    /**
     * @notice The get operators function.
     * @param _serviceManager The service manager address.
     * @param _quorumNumber The quorum number.
     * @return operators The operators.
     */
    function getOperators(
        address _serviceManager,
        uint8 _quorumNumber
    ) internal view returns (address[] memory) {
        WavsServiceManager serviceManager = WavsServiceManager(_serviceManager);

        IAllocationManager allocationManager =
            IAllocationManager(serviceManager.getAllocationManager());
        OperatorSet memory opSetQuery =
            OperatorSet({avs: address(serviceManager), id: _quorumNumber});
        address[] memory operators = allocationManager.getMembers(opSetQuery);

        return operators;
    }

    /**
     * @notice The read config function.
     * @param fileName The file name.
     * @return configData The config data.
     */
    function readConfig(
        string memory fileName
    ) internal returns (WavsListOperatorsLib.ConfigData memory) {
        if (!VM.exists(fileName)) {
            revert WavsListOperatorsLib__ConfigFileNotFound();
        }

        // load the complete config
        string memory json = VM.readFile(fileName);

        // Parse basic config data
        uint96 minimumStake = abi.decode(VM.parseJson(json, ".minimumStake"), (uint96));
        uint96 totalWeight = abi.decode(VM.parseJson(json, ".totalWeight"), (uint96));
        uint256 quorumNumerator = abi.decode(VM.parseJson(json, ".quorumNumerator"), (uint256));
        uint256 quorumDenominator = abi.decode(VM.parseJson(json, ".quorumDenominator"), (uint256));

        // Parse the strategies array from the JSON
        address[] memory strategies =
            abi.decode(VM.parseJson(json, ".strategies[*].strategy"), (address[]));
        uint256 strategyCount = strategies.length;
        uint96[] memory multipliers =
            abi.decode(VM.parseJson(json, ".strategies[*].multiplier"), (uint96[]));

        // Convert to strategy params
        IStakeRegistryTypes.StrategyParams[] memory strategyParams =
            new IStakeRegistryTypes.StrategyParams[](strategyCount);
        for (uint256 i; i < strategyCount; ++i) {
            strategyParams[i] = IStakeRegistryTypes.StrategyParams({
                strategy: IStrategy(strategies[i]),
                multiplier: multipliers[i]
            });
        }

        // Parse operators data
        address[] memory operatorAddresses =
            abi.decode(VM.parseJson(json, ".operators[*].operator"), (address[]));
        bytes32[] memory operatorIds =
            abi.decode(VM.parseJson(json, ".operators[*].operatorId"), (bytes32[]));
        uint256[] memory pubkeyXs =
            abi.decode(VM.parseJson(json, ".operators[*].pubkey.x"), (uint256[]));
        uint256[] memory pubkeyYs =
            abi.decode(VM.parseJson(json, ".operators[*].pubkey.y"), (uint256[]));
        string[] memory sockets = abi.decode(VM.parseJson(json, ".operators[*].socket"), (string[]));
        uint96[] memory stakes = abi.decode(VM.parseJson(json, ".operators[*].stake"), (uint96[]));

        // Parse G2 public keys (arrays of 2 uint256s)
        uint256[2][] memory pubkeyG2Xs =
            abi.decode(VM.parseJson(json, ".operators[*].pubkeyG2.x"), (uint256[2][]));
        uint256[2][] memory pubkeyG2Ys =
            abi.decode(VM.parseJson(json, ".operators[*].pubkeyG2.y"), (uint256[2][]));

        uint256 operatorCount = operatorAddresses.length;

        // Convert to operator data
        OperatorData[] memory operators = new OperatorData[](operatorCount);
        for (uint256 i; i < operatorCount; ++i) {
            operators[i] = OperatorData({
                operator: operatorAddresses[i],
                operatorId: operatorIds[i],
                pubkey: BN254.G1Point({X: pubkeyXs[i], Y: pubkeyYs[i]}),
                pubkeyG2: BN254.G2Point({X: pubkeyG2Xs[i], Y: pubkeyG2Ys[i]}),
                socket: sockets[i],
                stake: stakes[i]
            });
        }

        return ConfigData({
            totalWeight: totalWeight,
            minimumStake: minimumStake,
            strategies: strategyParams,
            operators: operators,
            quorumNumerator: quorumNumerator,
            quorumDenominator: quorumDenominator
        });
    }

    /**
     * @notice The write operator list JSON function.
     * @param configData The config data.
     */
    function writeOperatorListJson(
        ConfigData memory configData
    ) internal {
        if (!VM.exists("deployments/wavs-bls")) {
            VM.createDir("deployments/wavs-bls", true);
        }

        string memory json = "{\"totalWeight\":\"";
        json = string.concat(json, Strings.toString(configData.totalWeight));
        json = string.concat(json, "\",\"minimumStake\":\"");
        json = string.concat(json, Strings.toString(configData.minimumStake));
        json = string.concat(json, "\",\"strategies\":[");

        for (uint256 i = 0; i < configData.strategies.length; ++i) {
            if (i > 0) {
                json = string.concat(json, ",");
            }
            json = string.concat(json, "{\"strategy\":\"");
            json = string.concat(
                json, Strings.toHexString(uint160(address(configData.strategies[i].strategy)), 20)
            );
            json = string.concat(json, "\",\"multiplier\":\"");
            json = string.concat(json, Strings.toString(configData.strategies[i].multiplier));
            json = string.concat(json, "\"}");
        }

        json = string.concat(json, "],\"operators\":[");

        for (uint256 i = 0; i < configData.operators.length; ++i) {
            if (i > 0) {
                json = string.concat(json, ",");
            }
            json = string.concat(json, "{\"operator\":\"");
            json = string.concat(
                json, Strings.toHexString(uint160(configData.operators[i].operator), 20)
            );
            json = string.concat(json, "\",\"operatorId\":\"");
            json = string.concat(
                json, Strings.toHexString(uint256(configData.operators[i].operatorId), 32)
            );
            json = string.concat(json, "\",\"pubkey\":{");
            json = string.concat(json, "\"x\":\"");
            json = string.concat(
                json, Strings.toHexString(uint256(configData.operators[i].pubkey.X), 32)
            );
            json = string.concat(json, "\",\"y\":\"");
            json = string.concat(
                json, Strings.toHexString(uint256(configData.operators[i].pubkey.Y), 32)
            );
            json = string.concat(json, "\"},");
            json = string.concat(json, "\"pubkeyG2\":{");
            json = string.concat(json, "\"x\":[\"");
            json = string.concat(
                json, Strings.toHexString(uint256(configData.operators[i].pubkeyG2.X[0]), 32)
            );
            json = string.concat(
                json,
                "\",\"",
                Strings.toHexString(uint256(configData.operators[i].pubkeyG2.X[1]), 32)
            );
            json = string.concat(json, "\"],");
            json = string.concat(json, "\"y\":[\"");
            json = string.concat(
                json, Strings.toHexString(uint256(configData.operators[i].pubkeyG2.Y[0]), 32)
            );
            json = string.concat(
                json,
                "\",\"",
                Strings.toHexString(uint256(configData.operators[i].pubkeyG2.Y[1]), 32)
            );
            json = string.concat(json, "\"]},");
            json = string.concat(json, "\"socket\":\"");
            json = string.concat(json, configData.operators[i].socket);
            json = string.concat(json, "\",\"stake\":\"");
            json = string.concat(json, Strings.toString(configData.operators[i].stake));
            json = string.concat(json, "\"}");
        }

        json = string.concat(json, "],\"quorumNumerator\":\"");
        json = string.concat(json, Strings.toString(configData.quorumNumerator));
        json = string.concat(json, "\",\"quorumDenominator\":\"");
        json = string.concat(json, Strings.toString(configData.quorumDenominator));
        json = string.concat(json, "\"");
        json = string.concat(json, "}");

        VM.writeFile("deployments/wavs-bls/list_operators.json", json);
    }
}
