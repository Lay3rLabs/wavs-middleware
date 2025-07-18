// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Pausable} from "@eigenlayer/contracts/permissions/Pausable.sol";

/**
 * @title UnpauseWavsRegistration
 * @author Lay3rLabs
 * @notice This script unpauses the WAVS registration.
 * @dev This script is used to unpause the WAVS registration.
 */
contract UnpauseWavsRegistration is Script {
    using stdJson for *;

    string private constant ENV_REGISTRY_ADDRESS = "REGISTRY_ADDRESS";

    Pausable private slashingRegistryCoordinator;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        slashingRegistryCoordinator = Pausable(vm.envAddress(ENV_REGISTRY_ADDRESS));
    }

    /// @notice The run function for the script.
    function run() external {
        console.log(
            "Slashing Registry Coordinator address: %s", address(slashingRegistryCoordinator)
        );

        vm.startBroadcast();
        slashingRegistryCoordinator.unpause(0);
        console.log("Slashing Registry Coordinator is now unpaused");
        vm.stopBroadcast();
    }
}
