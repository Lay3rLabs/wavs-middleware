// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBLSApkRegistryTypes} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";

/**
 * @title IMirrorBLSApkRegistry
 * @author Lay3rLabs
 * @notice This interface defines the MirrorBLSApkRegistry contract.
 * @dev This interface is used to interact with the MirrorBLSApkRegistry contract.
 */
interface IMirrorBLSApkRegistry {
    /**
     * @notice The function to register a BLS public key for a mirror.
     * @param operator The operator.
     * @param params The parameters for the registration.
     * @return operatorId The ID of the operator.
     */
    function registerBLSPublicKeyForMirror(
        address operator,
        IBLSApkRegistryTypes.PubkeyRegistrationParams calldata params
    ) external returns (bytes32 operatorId);

    /**
     * @notice The function to get or register an operator ID for a mirror.
     * @param operator The operator.
     * @param params The parameters for the registration.
     * @return operatorId The ID of the operator.
     */
    function getOrRegisterOperatorIdForMirror(
        address operator,
        IBLSApkRegistryTypes.PubkeyRegistrationParams calldata params
    ) external returns (bytes32 operatorId);
}
