// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {IECDSAStakeRegistryTypes} from
    "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";

import {WavsMirrorDeploymentLib} from "./utils/WavsMirrorDeploymentLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";

/**
 * @title WavsMirrorPrepareDeploy
 * @author Lay3rLabs
 * @notice This script prepares the deployment of the WavsMirror contracts.
 * @dev This script is used to prepare the deployment of the WavsMirror contracts.
 */
contract WavsMirrorPrepareDeploy is Script, IECDSAStakeRegistryTypes {
    using UpgradeableProxyLib for address;

    /// @notice The environment variable for the WAVS service manager contract address.
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";
    /// @notice The environment variable to indicate POA deployment.
    string public constant ENV_IS_POA = "IS_POA";

    string private configFile;
    address private serviceManagerAddress;
    bool private isPOA;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        // read env vars
        configFile = "./deployments/wavs-mirror-config.json";
        serviceManagerAddress = vm.envAddress(ENV_SERVICE_MANAGER);
        isPOA = vm.envOr(ENV_IS_POA, false);
    }

    /// @notice The run function for the script.
    function run() external {
        vm.startBroadcast();

        // Pass in the configuration as a file, load it
        WavsMirrorDeploymentLib.InitialConfiguration memory configuration =
            WavsMirrorDeploymentLib.loadConfigurationFromChain(serviceManagerAddress, isPOA);

        // write the configuration to a file
        WavsMirrorDeploymentLib.writeConfiguration(configFile, configuration);

        vm.stopBroadcast();
    }
}
