// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IManagerUpdateTypes
 * @author Lay3r Labs
 * @notice Interface for the manager update types
 * @dev This interface defines the update types for the manager
 */
interface IManagerUpdateTypes {
    /// @notice The error for the invalid trigger ID.
    error InvalidTriggerId(uint64 expectedTriggerId);

    /**
     * @notice DataWithId is a struct containing a trigger ID and updated operator info
     * @param triggerId The trigger ID
     * @param numerator The numerator
     * @param denominator The denominator
     */
    struct UpdateWithId {
        uint64 triggerId;
        uint256 numerator;
        uint256 denominator;
    }
}
