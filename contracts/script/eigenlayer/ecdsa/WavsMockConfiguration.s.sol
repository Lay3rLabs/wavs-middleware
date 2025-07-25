// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";

import {WavsMockDeploymentLib} from "./utils/WavsMockDeploymentLib.sol";

/**
 * @title WavsMockConfiguration
 * @author Lay3rLabs
 * @notice This script configures the WavsMock contracts.
 * @dev This script is used to configure the WavsMock contracts.
 */
contract WavsMockConfiguration is Script {
    /// @notice The environment variable for the service manager address.
    string public constant ENV_SERVICE_MANAGER = "MOCK_SERVICE_MANAGER_ADDRESS";
    /// @notice The environment variable for the configuration file.
    string public constant ENV_CONFIGURATION = "CONFIGURE_FILE";

    /// @notice The initial configuration.
    WavsMockDeploymentLib.InitialConfiguration public configuration;
    /// @notice The WAVS service manager address.
    address public serviceManagerAddress;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        // Pass in the configuration as a file, load it
        string memory configFile =
            string.concat("./deployments/", vm.envString(ENV_CONFIGURATION), ".json");
        configuration = WavsMockDeploymentLib.loadConfiguration(configFile);

        serviceManagerAddress = vm.envAddress(ENV_SERVICE_MANAGER);
    }

    /// @notice The run function for the script.
    function run() external {
        vm.startBroadcast();

        // initialize the operator set
        console2.log("Configuring initial state...");
        WavsMockDeploymentLib.setInitialConfiguration(serviceManagerAddress, configuration);

        vm.stopBroadcast();
    }
}
