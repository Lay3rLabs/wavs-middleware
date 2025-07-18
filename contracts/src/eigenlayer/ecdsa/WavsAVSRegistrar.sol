// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IAVSRegistrar} from "@eigenlayer/contracts/interfaces/IAVSRegistrar.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WavsAVSRegistrar
 * @author Lay3r Labs
 * @notice Minimal AVS Registrar contract.
 * @dev It allows the owner to pause the registration, preventing all Operator register and deregister operations.
 */
contract WavsAVSRegistrar is IAVSRegistrar, Ownable {
    /// @notice Whether the registration is paused
    bool public isPaused;

    /// @notice Error thrown when the registration is paused
    error WavsAVSRegistrar__Paused();

    /// @notice Modifier to check if the registration is paused
    modifier notPaused() {
        if (isPaused) {
            revert WavsAVSRegistrar__Paused();
        }
        _;
    }

    /// @notice Constructor
    constructor() Ownable() {
        isPaused = false;
    }

    /// @notice Pauses the registration
    function pause() external onlyOwner {
        isPaused = true;
    }

    /// @notice Unpauses the registration
    function unpause() external onlyOwner {
        isPaused = false;
    }

    /// @inheritdoc IAVSRegistrar
    function registerOperator(
        address, /* operator */
        address, /* avs */
        uint32[] calldata, /* operatorSetIds */
        bytes calldata /* data */
    ) external override notPaused {
        // TODO: Implement registration logic
    }

    /// @inheritdoc IAVSRegistrar
    function deregisterOperator(
        address, /* operator */
        address, /* avs */
        uint32[] calldata /* operatorSetIds */
    ) external override notPaused {
        // TODO: Implement deregistration logic
    }

    /// @inheritdoc IAVSRegistrar
    function supportsAVS(
        address /* avs */
    ) external pure override returns (bool) {
        // TODO: Implement logic to check if AVS is supported
        return true; // Placeholder return value
    }

    /// @notice Fallback function
    fallback() external {}
}
