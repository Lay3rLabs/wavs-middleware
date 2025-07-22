// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IWavsServiceHandler} from "../interfaces/IWavsServiceHandler.sol";
import {WavsServiceManager} from "../WavsServiceManager.sol";
import {IWavsOperatorUpdateHandler} from "../interfaces/IWavsOperatorUpdateHandler.sol";

/**
 * @title WavsOperatorUpdateHandler
 * @author Lay3r Labs
 * @notice Contract for syncing operator weights from the
 * @dev This contract implements the IMirrorQuorumSyncHandler and IWavsServiceHandler interfaces
 */
contract WavsOperatorUpdateHandler is IWavsOperatorUpdateHandler, IWavsServiceHandler {
    /// @notice Service manager instance
    WavsServiceManager public immutable SERVICE_MANAGER;

    /// @notice ECDSA stake registry instance
    ECDSAStakeRegistry public immutable ECDSA_STAKE_REGISTRY;

    /**
     * @notice Constructor
     * @param _serviceManager The service manager instance
     * @param _ecdsaStakeRegistry The ECDSA stake registry instance
     */
    constructor(WavsServiceManager _serviceManager, ECDSAStakeRegistry _ecdsaStakeRegistry) {
        SERVICE_MANAGER = _serviceManager;
        ECDSA_STAKE_REGISTRY = _ecdsaStakeRegistry;
    }

    /// @inheritdoc IWavsServiceHandler
    function handleSignedEnvelope(
        Envelope calldata envelope,
        SignatureData calldata signatureData
    ) external {
        SERVICE_MANAGER.validate(envelope, signatureData);

        OperatorUpdatePayload memory payload = abi.decode(envelope.payload, (OperatorUpdatePayload));

        //NOTE: any block limits we should worry about here?
        //NOTE: writer go code uses retry mechanism for this: https://github.com/Layr-Labs/eigenlayer-middleware/blob/3fb5b61076475108bd87d4e6c7352fd60b46af1c/src/interfaces/ISlashingRegistryCoordinator.sol#L362-L363
        ECDSA_STAKE_REGISTRY.updateOperatorsForQuorum(
            payload.operatorsPerQuorum, payload.quorumNumbers
        );
    }

    /// @inheritdoc IWavsServiceHandler
    function getServiceManager() external view returns (address) {
        return address(SERVICE_MANAGER);
    }

    /**
     * @notice Returns the address of the ECDSA stake registry
     * @return The address of the ECDSA stake registry
     */
    function getStakeRegistry() external view returns (address) {
        return address(ECDSA_STAKE_REGISTRY);
    }
}
