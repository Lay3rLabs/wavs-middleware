// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

/**
 * @title IWavsServiceManager
 * @author Lay3r Labs
 * @notice Interface for the WavsServiceManager contract
 * @dev This interface defines the functions and events for the WavsServiceManager contract
 */
interface IWavsServiceManager {
    /// @notice The error for the invalid quorum parameters.
    error InvalidQuorumParameters();

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------
    /**
     * @notice Event emitted when the service URI is updated
     * @param serviceURI The service URI
     */
    event ServiceURIUpdated(string serviceURI);
    /**
     * @notice Event emitted when the quorum threshold is updated
     * @param numerator The numerator of the quorum threshold
     * @param denominator The denominator of the quorum threshold
     */
    event QuorumThresholdUpdated(uint256 indexed numerator, uint256 indexed denominator);

    /**
     * @notice Returns the service URI.
     * @return The service URI.
     */
    function getServiceURI() external view returns (string memory);

    /**
     * @notice Updates the service URI.
     * @param _serviceURI The service URI to update.
     */
    function setServiceURI(
        string calldata _serviceURI
    ) external;

    /**
     * @notice Sets a new quorum threshold for signature validation
     * @param numerator The numerator of the quorum fraction
     * @param denominator The denominator of the quorum fraction
     * @dev The fraction numerator/denominator represents the minimum portion of stake
     *      required for a valid signature (e.g., 2/3 or 51/100)
     */
    function setQuorumThreshold(
        uint256 numerator,
        uint256 denominator
    ) external;

    /**
     * @notice Returns the address of the registry coordinator.
     * @return The address of the registry coordinator.
     */
    function getRegistryCoordinator() external view returns (address);

    /**
     * @notice Returns the address of the allocation manager.
     * @return The address of the allocation manager.
     */
    function getAllocationManager() external view returns (address);

    /**
     * @notice Returns the address of the stake registry.
     * @return The address of the stake registry.
     */
    function getStakeRegistry() external view returns (address);
}
