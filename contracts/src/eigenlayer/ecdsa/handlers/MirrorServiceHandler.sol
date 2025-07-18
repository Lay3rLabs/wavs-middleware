// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IWavsServiceHandler} from "../interfaces/IWavsServiceHandler.sol";
import {IWavsServiceManager} from "../interfaces/IWavsServiceManager.sol";
import {MirrorStakeRegistry} from "../MirrorStakeRegistry.sol";
import {IMirrorUpdateTypes} from "../interfaces/IMirrorServiceHandler.sol";

/**
 * @title MirrorServiceHandler
 * @author Lay3r Labs
 * @notice Contract for handling the Mirror service
 * @dev This contract implements the IWavsServiceHandler interface
 */
contract MirrorServiceHandler is IMirrorUpdateTypes, IWavsServiceHandler {
    /// @notice Ensures all updates are deployed in order and no duplicates.
    uint64 public lastTriggerId;

    /// @notice Stake Registry instance
    MirrorStakeRegistry public immutable STAKE_REGISTRY;

    /// @notice Service manager instance
    IWavsServiceManager public immutable SERVICE_MANAGER;

    /**
     * @notice Constructor
     * @param _stakeRegistry The stake registry instance
     */
    constructor(
        MirrorStakeRegistry _stakeRegistry
    ) {
        STAKE_REGISTRY = _stakeRegistry;
        SERVICE_MANAGER = IWavsServiceManager(_stakeRegistry.serviceManager());
        lastTriggerId = 0;
    }

    /// @inheritdoc IWavsServiceHandler
    function handleSignedEnvelope(
        Envelope calldata envelope,
        SignatureData calldata signatureData
    ) external {
        // Quick check this is valid trigger id before validating signatures
        UpdateWithId memory updateData = abi.decode(envelope.payload, (UpdateWithId));
        if (!(updateData.triggerId > lastTriggerId)) {
            revert InvalidTriggerId(lastTriggerId);
        }

        // Validate the signatures and update trigger id at this point
        SERVICE_MANAGER.validate(envelope, signatureData);
        lastTriggerId = updateData.triggerId;

        // call stake registry to update
        STAKE_REGISTRY.updateStakeThreshold(updateData.thresholdWeight);
        STAKE_REGISTRY.batchSetOperatorDetails(
            updateData.operators, updateData.signingKeyAddresses, updateData.weights
        );
    }

    /// @inheritdoc IWavsServiceHandler
    function getServiceManager() external view returns (address) {
        return address(SERVICE_MANAGER);
    }

    /**
     * @notice Returns the address of the stake registry
     * @return The address of the stake registry
     */
    function getStakeRegistry() external view returns (address) {
        return address(STAKE_REGISTRY);
    }
}
