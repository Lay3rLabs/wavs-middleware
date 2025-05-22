// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IAVSRegistrar} from "@eigenlayer/contracts/interfaces/IAVSRegistrar.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Minimal AVS Registrar contract. 
// It allows the owner to pause the registration, preventing all Operator register and deregister operations.
contract WavsAVSRegistrar is IAVSRegistrar, Ownable {
    bool public isPaused;

    constructor() Ownable() {
        isPaused = false;
    }

    function pause() external onlyOwner {
        isPaused = true;
    }

    function unpause() external onlyOwner {
        isPaused = false;
    }

    modifier notPaused() {
        require(!isPaused, "AVSRegistrar: paused");
        _;
    }

    function registerOperator(
        address operator,
        address avs,
        uint32[] calldata operatorSetIds,
        bytes calldata data
    ) external override notPaused {
        // TODO: Implement registration logic
    }

    function deregisterOperator(
        address operator,
        address avs,
        uint32[] calldata operatorSetIds
    ) external override notPaused {
        // TODO: Implement deregistration logic
    }

    function supportsAVS(
        address /* avs */
    ) external pure override returns (bool) {
        // TODO: Implement logic to check if AVS is supported
        return true; // Placeholder return value
    }

    fallback () external {}
}
