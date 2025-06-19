// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IECDSAStakeRegistryTypes} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";

import {WavsMirrorDeploymentLib} from "./utils/WavsMirrorDeploymentLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";

contract WavsMirrorPrepareDeploy is Script, IECDSAStakeRegistryTypes {
    using UpgradeableProxyLib for address;

    string public constant ENV_CONFIG_FILE = "WAVS_MIRROR_CONFIG";
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";

    string private configFile;
    address private serviceManagerAddress;

    function setUp() public virtual {
        // read env vars
        configFile = vm.envString(ENV_CONFIG_FILE);
        serviceManagerAddress = vm.envAddress(ENV_SERVICE_MANAGER);
    }

    function run() external {
        vm.startBroadcast();

        // Pass in the configuration as a file, load it
        WavsMirrorDeploymentLib.InitialConfiguration memory configuration =
            WavsMirrorDeploymentLib.loadConfigurationFromChain(serviceManagerAddress);

        // write the configuration to a file
        WavsMirrorDeploymentLib.writeConfiguration(configFile, configuration);

        vm.stopBroadcast();
    }
}
