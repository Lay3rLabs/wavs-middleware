// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IWavsServiceHandler.sol";

interface IWavsServiceAggregator {
    /**
     * @notice Multi-payload version of handleSignedData
     * @param envelopes The envelopes containing the datas that were signed.
     * @param signatures The signatures of the datas.
     */
    function handleSignedDataMulti(IWavsServiceHandler.Envelope[] calldata envelopes, bytes[] calldata signatures) external;
}
