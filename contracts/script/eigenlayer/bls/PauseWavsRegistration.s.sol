// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Pausable} from "@eigenlayer/contracts/permissions/Pausable.sol";

// Required: set private key, mnemonic, or hardware key for contract owner to forge script
// Optional: AVS_DEPLOY_FILE (defaults to /root/.nodes/avs_deploy.json)
contract PauseWavsRegistration is Script {
    using stdJson for *;

    string private constant ENV_REGISTRY_ADDRESS = "REGISTRY_ADDRESS";

    Pausable private slashingRegistryCoordinator;

    function setUp() public virtual {
        slashingRegistryCoordinator = Pausable(vm.envAddress(ENV_REGISTRY_ADDRESS));
    }

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
