// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWavsServiceHandler} from "../interfaces/IWavsServiceHandler.sol";
import {IWavsServiceAggregator} from "../interfaces/IWavsServiceAggregator.sol";

/**
 * @title WavsServiceAggregator
 * @notice Contract that takes aggregates calls to a IWavsServiceHandler
 */
contract WavsServiceAggregator is IWavsServiceAggregator {
    IWavsServiceHandler private _handler;

    constructor(IWavsServiceHandler handler) {
        _handler = handler;
    }
    // ------------------------------------------------------------------------
    // Custom Errors
    // ------------------------------------------------------------------------
    error InvalidLength();

    function getHandler() external view returns (IWavsServiceHandler) {
        return _handler;
    }
    /**
     * @notice Multi-payload version of the handler's handleSignedData
     * @param envelopes The envelopes containing the datas that were signed.
     * @param signatures The signatures of the datas.
     */
    function handleSignedDataMulti(IWavsServiceHandler.Envelope[] calldata envelopes, bytes[] calldata signatures) external {
        if (envelopes.length != signatures.length) {
            revert InvalidLength();
        }
        for (uint256 i = 0; i < envelopes.length; i++) {
            _handler.handleSignedEnvelope(envelopes[i], signatures[i]);
        }
    }
}
