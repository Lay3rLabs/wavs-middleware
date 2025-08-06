// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";
import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";

import {ISlashingRegistryCoordinator} from
    "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IMirrorBLSApkRegistry} from "../interfaces/IMirrorBLSApkRegistry.sol";

/**
 * @title MirrorBLSApkRegistry
 * @author Lay3rLabs
 * @notice This contract implements the MirrorBLSApkRegistry contract.
 * @dev This contract is used to register and get BLS public keys for a mirror.
 */
contract MirrorBLSApkRegistry is BLSApkRegistry, IMirrorBLSApkRegistry {
    /**
     * @notice The constructor for the MirrorBLSApkRegistry contract.
     * @param _registryCoordinator The registry coordinator.
     */
    constructor(
        ISlashingRegistryCoordinator _registryCoordinator
    ) BLSApkRegistry(_registryCoordinator) {}

    /// @inheritdoc IMirrorBLSApkRegistry
    function registerBLSPublicKeyForMirror(
        address operator,
        PubkeyRegistrationParams calldata params
    ) public onlyRegistryCoordinator returns (bytes32) {
        bytes32 pubkeyHash = BN254.hashG1Point(params.pubkeyG1);
        require(pubkeyHash != ZERO_PK_HASH, ZeroPubKey());
        require(getOperatorId(operator) == bytes32(0), OperatorAlreadyRegistered());
        require(pubkeyHashToOperator[pubkeyHash] == address(0), BLSPubkeyAlreadyRegistered());

        operatorToPubkey[operator] = params.pubkeyG1;
        operatorToPubkeyG2[operator] = params.pubkeyG2;
        operatorToPubkeyHash[operator] = pubkeyHash;
        pubkeyHashToOperator[pubkeyHash] = operator;

        emit NewPubkeyRegistration(operator, params.pubkeyG1, params.pubkeyG2);
        return pubkeyHash;
    }

    /// @inheritdoc IMirrorBLSApkRegistry
    function getOrRegisterOperatorIdForMirror(
        address operator,
        PubkeyRegistrationParams calldata params
    ) external onlyRegistryCoordinator returns (bytes32 operatorId) {
        operatorId = getOperatorId(operator);
        if (operatorId == 0) {
            operatorId = registerBLSPublicKeyForMirror(operator, params);
        }
        return operatorId;
    }
}
