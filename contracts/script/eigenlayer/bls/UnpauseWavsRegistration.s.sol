// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Pausable} from "@eigenlayer/contracts/permissions/Pausable.sol";

// Required: set private key, mnemonic, or hardware key for contract owner to forge script
// Optional: AVS_DEPLOY_FILE (defaults to /root/.nodes/avs_deploy.json)
contract UnpauseWavsRegistration is Script {
    using stdJson for *;

    string private constant ENV_SLASHING_REGISTRY_COORDINATOR_ADDRESS =
        "SLASHING_REGISTRY_COORDINATOR_ADDRESS";

    Pausable private slashingRegistryCoordinator;

    function setUp() public virtual {
        slashingRegistryCoordinator =
            Pausable(vm.envAddress(ENV_SLASHING_REGISTRY_COORDINATOR_ADDRESS));
    }

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
