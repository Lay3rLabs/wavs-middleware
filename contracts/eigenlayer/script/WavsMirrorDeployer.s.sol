// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
import {WavsMirrorDeploymentLib} from "./utils/WavsMirrorDeploymentLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";


import {
    IECDSAStakeRegistryTypes,
    IStrategy
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";

contract WavsMirrorDeployer is Script, IECDSAStakeRegistryTypes {
    using UpgradeableProxyLib for address;

    string public constant ENV_CONFIG_FILE = "WAVS_MIRROR_CONFIG";

    address proxyAdmin;
    WavsMirrorDeploymentLib.DeploymentData deployment;
    WavsMirrorDeploymentLib.InitialConfiguration configuration;

    function setUp() public virtual {
        // Pass in the configuration as a file, load it
        string memory configFile = vm.envString(ENV_CONFIG_FILE);
        configuration = WavsMirrorDeploymentLib.loadConfiguration(configFile);
    }

    function run() external {
        vm.startBroadcast();
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        // deploy middleware contracts
        console2.log("Deploying contracts...");
        deployment = WavsMirrorDeploymentLib.deployContracts(proxyAdmin);
        
        // initialize the operator set
        console2.log("Configuraing initial state...");
        WavsMirrorDeploymentLib.setInitialConfiguration(deployment, configuration);

        // deploy the handlers
        console2.log("Deploying ServiceHandlers as admin...");
        WavsMirrorDeploymentLib.deployServiceHandlers(deployment);

        vm.stopBroadcast();

        verifyDeployment();
        WavsMirrorDeploymentLib.writeDeploymentJson(deployment);
    }

    function verifyDeployment() internal view {
        require(
            deployment.stakeRegistry != address(0), "StakeRegistry address cannot be zero"
        );
        require(
            deployment.WavsServiceManager != address(0),
            "WavsServiceManager address cannot be zero"
        );
        require(
            deployment.MirrorServiceHandler != address(0),
            "MirrorServiceHandler address cannot be zero"
        );
        require(
            deployment.MirrorServiceManagerHandler != address(0),
            "MirrorServiceManagerHandler address cannot be zero"
        );
        require(proxyAdmin != address(0), "ProxyAdmin address cannot be zero");
    }
}
