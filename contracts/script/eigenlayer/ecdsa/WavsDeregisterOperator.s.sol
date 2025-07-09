// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {WavsRegisterOperatorLib} from "./utils/WavsRegisterOperatorLib.sol";

contract WavsDeregisterOperator is Script {
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";

    address private serviceManagerAddress;

    function setUp() public virtual {
        // Get the configuration from environment
        serviceManagerAddress = vm.envAddress(ENV_SERVICE_MANAGER);
    }

    function run() external {
        vm.startBroadcast();

        WavsRegisterOperatorLib.deregisterFromAvs(serviceManagerAddress);

        vm.stopBroadcast();
    }
}
