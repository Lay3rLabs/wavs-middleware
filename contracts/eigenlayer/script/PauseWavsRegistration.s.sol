// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {WavsAVSRegistrar} from "../src/WavsAVSRegistrar.sol";
import {stdJson} from "forge-std/StdJson.sol";

// Required: set private key, mnemonic, or hardware key for contract owner to forge script
// Optional: AVS_DEPLOY_FILE (defaults to /root/.nodes/avs_deploy.json)
contract PauseWavsRegistration is Script {
    using stdJson for *;

    WavsAVSRegistrar private avsRegistrar;

    function setUp() public virtual {
        // we read from /root/.nodes/avs_deploy.json
        string memory defaultValue = "/root/.nodes/avs_deploy.json";
        string memory fileName = vm.envOr("AVS_DEPLOY_FILE", defaultValue);

        require(vm.exists(fileName), "Deployment file does not exist");
        string memory json = vm.readFile(fileName);
        avsRegistrar = WavsAVSRegistrar(json.readAddress(".addresses.avsRegistrar"));
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

        require(isPaused, "Failed to pause AVS Registrar");
        console.logString("AVS Registrar is now paused");
    }
}
