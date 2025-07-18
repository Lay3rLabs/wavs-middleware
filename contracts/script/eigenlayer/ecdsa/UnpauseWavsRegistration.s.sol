// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {WavsAVSRegistrar} from "src/eigenlayer/ecdsa/WavsAVSRegistrar.sol";

/**
 * @title UnpauseWavsRegistration
 * @author Lay3rLabs
 * @notice This script unpauses the WAVS registration.
 * @dev This script is used to unpause the WAVS registration.
 */
contract UnpauseWavsRegistration is Script {
    using stdJson for *;

    /// @notice The environment variable for the AVS registrar address.
    string public constant ENV_REGISTRY_ADDRESS = "REGISTRY_ADDRESS";

    WavsAVSRegistrar private avsRegistrar;

    /// @notice The error for the failed to unpause the AVS registrar.
    error UnpauseWavsRegistration__FailedToUnpauseAVSRegistrar();

    /// @notice The setup function for the script.
    function setUp() public virtual {
        // we read from /root/.nodes/avs_deploy.json
        avsRegistrar = WavsAVSRegistrar(vm.envAddress(ENV_REGISTRY_ADDRESS));
    }

    /// @notice The run function for the script.
    function run() external {
        console.log("AVS Registrar address: %s", address(avsRegistrar));

        vm.startBroadcast();
        bool isPaused = avsRegistrar.isPaused();
        if (!isPaused) {
            console.logString("AVS Registrar is already unpaused");
            return;
        }

        avsRegistrar.unpause();
        isPaused = avsRegistrar.isPaused();
        vm.stopBroadcast();

        if (isPaused) {
            revert UnpauseWavsRegistration__FailedToUnpauseAVSRegistrar();
        }
        console.logString("AVS Registrar is now unpaused");
    }
}
