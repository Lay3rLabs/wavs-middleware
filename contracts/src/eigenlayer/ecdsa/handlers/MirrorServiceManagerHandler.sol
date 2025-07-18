// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IWavsServiceHandler} from "../interfaces/IWavsServiceHandler.sol";
import {WavsServiceManager} from "../WavsServiceManager.sol";
import {IManagerUpdateTypes} from "../interfaces/IMirrorServiceManagerHandler.sol";

/**
 * @title MirrorServiceManagerHandler
 * @author Lay3r Labs
 * @notice Contract for handling the Mirror service manager
 * @dev This contract implements the IManagerUpdateTypes and IWavsServiceHandler interfaces
 */
contract MirrorServiceManagerHandler is IManagerUpdateTypes, IWavsServiceHandler {
    /// @notice Ensures all updates are deployed in order and no duplicates.
    uint64 public lastTriggerId;

    /// @notice Service manager instance
    WavsServiceManager public immutable SERVICE_MANAGER;

    /**
     * @notice Constructor
     * @param _serviceManager The service manager instance
     */
    constructor(
        WavsServiceManager _serviceManager
    ) {
        SERVICE_MANAGER = _serviceManager;
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
        SERVICE_MANAGER.setQuorumThreshold(updateData.numerator, updateData.denominator);
    }

    /// @inheritdoc IWavsServiceHandler
    function getServiceManager() external view returns (address) {
        return address(SERVICE_MANAGER);
    }
}
