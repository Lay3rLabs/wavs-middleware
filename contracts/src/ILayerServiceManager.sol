// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ILayerServiceManager {
    // ------------------------------------------------------------------------
    // Custom Errors
    // ------------------------------------------------------------------------
    error InvalidSignature();
    event ServiceURIUpdated(string serviceURI);
    /**
     * @param data The arbitrary data that was signed.
     * @param signature The signature of the data.
     */
    function validate(bytes calldata data, bytes calldata signature) external view;

    /**
     * @return The service URI.
     */
    function getServiceURI() external view returns (string memory);

    /**
     * @param _serviceURI The service URI to update.
     */
    function setServiceURI(string calldata _serviceURI) external;
}