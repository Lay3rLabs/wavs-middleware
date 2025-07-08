// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

interface IWavsServiceManager {
    error InvalidQuorumParameters();

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------
    event ServiceURIUpdated(string serviceURI);
    event QuorumThresholdUpdated(uint256 numerator, uint256 denominator);

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
    function setQuorumThreshold(uint256 numerator, uint256 denominator) external;
}
