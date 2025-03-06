// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IAVSRegistrar} from "@eigenlayer/contracts/interfaces/IAVSRegistrar.sol";

// TODO: decide on AVSRegistar logic
// Dummy AVSRegistrar contract for now
contract LayerAVSRegistrar is IAVSRegistrar {
    function registerOperator(
        address operator,
        address avs,
        uint32[] calldata operatorSetIds,
        bytes calldata data
    ) external override {
        // TODO: Implement registration logic
    }

    function deregisterOperator(
        address operator,
        address avs,
        uint32[] calldata operatorSetIds
    ) external override {
        // TODO: Implement deregistration logic
    }

    function supportsAVS(
        address avs
    ) external view override returns (bool) {
        // TODO: Implement logic to check if AVS is supported
        return true; // Placeholder return value
    }

    fallback () external {}
}
