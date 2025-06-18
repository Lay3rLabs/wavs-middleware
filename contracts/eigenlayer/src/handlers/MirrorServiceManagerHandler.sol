// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWavsServiceHandler} from "../../../interfaces/IWavsServiceHandler.sol";
import {WavsServiceManager} from "../WavsServiceManager.sol";

interface IManagerUpdateTypes {
    error InvalidTriggerId(uint64 expectedTriggerId);

    /// @notice DataWithId is a struct containing a trigger ID and updated operator info
    struct UpdateWithId {
        uint64 triggerId;
        uint256 numerator;
        uint256 denominator;
    }
}

contract MirrorServiceManagerHandler is IManagerUpdateTypes, IWavsServiceHandler {
    /// @notice Ensures all updates are deployed in order and no duplicates.
    uint64 public lastTriggerId;

    /// @notice Service manager instance
    WavsServiceManager public serviceManager;

    constructor(WavsServiceManager _serviceManager) {
        serviceManager = _serviceManager;
        lastTriggerId = 0;
    }

    function handleSignedEnvelope(Envelope calldata envelope, SignatureData calldata signatureData) external {
        // Quick check this is valid trigger id before validating signatures
        IManagerUpdateTypes.UpdateWithId memory updateData =
            abi.decode(envelope.payload, (IManagerUpdateTypes.UpdateWithId));
        if (updateData.triggerId <= lastTriggerId) {
            revert InvalidTriggerId(lastTriggerId);
        }

        // Validate the signatures and update trigger id at this point
        serviceManager.validate(envelope, signatureData);
        lastTriggerId = updateData.triggerId;

        // call stake registry to update
        serviceManager.setQuorumThreshold(updateData.numerator, updateData.denominator);
    }
}
