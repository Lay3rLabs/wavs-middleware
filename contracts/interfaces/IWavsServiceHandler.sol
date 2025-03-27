// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWavsServiceHandler {

    struct Envelope {
        bytes data;
    }

    /**
     * @param envelope The envelope containing the data.
     * @param signature The signature of the data.
     */
    function handleSignedEnvelope(Envelope calldata envelope, bytes calldata signature) external;
}
