// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IMirrorUpdateTypes
 * @author Lay3r Labs
 * @notice Interface for the Mirror update types
 * @dev This interface defines the update types for the Mirror service
 */
interface IMirrorUpdateTypes {
    /// @notice The error for the invalid trigger ID.
    error InvalidTriggerId(uint64 expectedTriggerId);

    /**
     * @notice DataWithId is a struct containing a trigger ID and updated operator info
     * @param triggerId The trigger ID
     * @param thresholdWeight The threshold weight
     * @param operators The operators
     * @param signingKeyAddresses The signing key addresses
     * @param weights The weights
     */
    struct UpdateWithId {
        uint64 triggerId;
        uint256 thresholdWeight;
        address[] operators;
        address[] signingKeyAddresses;
        uint256[] weights;
    }
}
