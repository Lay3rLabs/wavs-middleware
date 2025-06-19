// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWavsServiceHandler} from "../../../interfaces/IWavsServiceHandler.sol";
import {IWavsServiceManager} from "../../../interfaces/IWavsServiceManager.sol";
import {MirrorStakeRegistry} from "../MirrorStakeRegistry.sol";

interface IMirrorUpdateTypes {
    error InvalidTriggerId(uint64 expectedTriggerId);

    /// @notice DataWithId is a struct containing a trigger ID and updated operator info
    struct UpdateWithId {
        uint64 triggerId;
        uint256 thresholdWeight;
        address[] operators;
        address[] signingKeys;
        uint256[] weights;
    }
}

contract MirrorServiceHandler is IMirrorUpdateTypes, IWavsServiceHandler {
    /// @notice Ensures all updates are deployed in order and no duplicates.
    uint64 public lastTriggerId;

    /// @notice Stake Registry instance
    MirrorStakeRegistry public stakeRegistry;

    /// @notice Service manager instance
    IWavsServiceManager public serviceManager;

    constructor(
        MirrorStakeRegistry _stakeRegistry
    ) {
        stakeRegistry = _stakeRegistry;
        serviceManager = IWavsServiceManager(_stakeRegistry.serviceManager());
        lastTriggerId = 0;
    }

    function handleSignedEnvelope(
        Envelope calldata envelope,
        SignatureData calldata signatureData
    ) external {
        // Quick check this is valid trigger id before validating signatures
        IMirrorUpdateTypes.UpdateWithId memory updateData =
            abi.decode(envelope.payload, (IMirrorUpdateTypes.UpdateWithId));
        if (updateData.triggerId <= lastTriggerId) {
            revert InvalidTriggerId(lastTriggerId);
        }

        // Validate the signatures and update trigger id at this point
        serviceManager.validate(envelope, signatureData);
        lastTriggerId = updateData.triggerId;

        // call stake registry to update
        stakeRegistry.updateStakeThreshold(updateData.thresholdWeight);
        stakeRegistry.batchSetOperatorDetails(
            updateData.operators, updateData.signingKeys, updateData.weights
        );
    }
}
