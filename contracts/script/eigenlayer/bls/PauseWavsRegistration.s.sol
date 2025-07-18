// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Pausable} from "@eigenlayer/contracts/permissions/Pausable.sol";

/**
 * @title PauseWavsRegistration
 * @author Lay3rLabs
 * @notice This script pauses the WAVS registration.
 * @dev This script is used to pause the WAVS registration.
 */
contract PauseWavsRegistration is Script {
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
        slashingRegistryCoordinator.pauseAll();
        console.log("Slashing Registry Coordinator is now paused");
        vm.stopBroadcast();
    }
}
