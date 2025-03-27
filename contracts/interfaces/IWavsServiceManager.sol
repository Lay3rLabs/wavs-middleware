// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./IWavsServiceHandler.sol";

interface IWavsServiceManager {
    // ------------------------------------------------------------------------
    // Custom Errors
    // ------------------------------------------------------------------------
    error InvalidSignature();
    event ServiceURIUpdated(string serviceURI);
    /**
     * @param envelope The envelope containing the data.
     * @param signature The signature of the data.
     */
    function validate(IWavsServiceHandler.Envelope calldata envelope, bytes calldata signature) external view;

    /**
     * @return The service URI.
     */
    function getServiceURI() external view returns (string memory);

    /**
     * @param _serviceURI The service URI to update.
     */
    function setServiceURI(string calldata _serviceURI) external;
}