// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {WavsRegisterOperatorLib} from "./utils/WavsRegisterOperatorLib.sol";

/**
 * @title WavsDeregisterOperator
 * @author Lay3rLabs
 * @notice This script deregisters an operator from the WavsServiceManager contract.
 * @dev This script is used to deregister an operator from the WavsServiceManager contract.
 */
contract WavsDeregisterOperator is Script {
    /// @notice The environment variable for the WAVS service manager address.
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";

    address private serviceManagerAddress;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        // Get the configuration from environment
        serviceManagerAddress = vm.envAddress(ENV_SERVICE_MANAGER);
    }

    /// @notice The run function for the script.
    function run() external {
        vm.startBroadcast();

        WavsRegisterOperatorLib.deregisterFromAvs(serviceManagerAddress);

        vm.stopBroadcast();
    }
}
