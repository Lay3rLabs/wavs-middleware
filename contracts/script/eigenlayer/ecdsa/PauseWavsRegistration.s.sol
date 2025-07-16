// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {WavsAVSRegistrar} from "src/eigenlayer/ecdsa/WavsAVSRegistrar.sol";

// Required: set private key, mnemonic, or hardware key for contract owner to forge script
// Required: AVS_REGISTRAR_ADDRESS (defaults to /root/.nodes/avs_deploy.json)
contract PauseWavsRegistration is Script {
    using stdJson for *;

    string public constant ENV_REGISTRY_ADDRESS = "REGISTRY_ADDRESS";

    WavsAVSRegistrar private avsRegistrar;

    error PauseWavsRegistration__FailedToPauseAVSRegistrar();

    function setUp() public virtual {
        // we read from /root/.nodes/avs_deploy.json
        avsRegistrar = WavsAVSRegistrar(vm.envAddress(ENV_REGISTRY_ADDRESS));
    }

    function run() external {
        console.log("AVS Registrar address: %s", address(avsRegistrar));

        vm.startBroadcast();
        bool isPaused = avsRegistrar.isPaused();
        if (isPaused) {
            console.logString("AVS Registrar is already paused");
            return;
        }

        avsRegistrar.pause();
        isPaused = avsRegistrar.isPaused();
        vm.stopBroadcast();

        if (!isPaused) {
            revert PauseWavsRegistration__FailedToPauseAVSRegistrar();
        }
        console.logString("AVS Registrar is now paused");
    }
}
