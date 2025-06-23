// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";

import {WavsMockDeploymentLib} from "./utils/WavsMockDeploymentLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";

contract WavsMockDeployer is Script {
    using UpgradeableProxyLib for address;

    string public constant ENV_CONFIG_FILE = "WAVS_MOCK_CONFIG";

    address public proxyAdmin;
    WavsMockDeploymentLib.DeploymentData public deployment;
    WavsMockDeploymentLib.InitialConfiguration public configuration;

    error WavsMockDeployer__StakeRegistryAddressCannotBeZero();
    error WavsMockDeployer__WavsServiceManagerAddressCannotBeZero();
    error WavsMockDeployer__ProxyAdminAddressCannotBeZero();

    function setUp() public virtual {
        // Pass in the configuration as a file, load it
        string memory configFile = vm.envString(ENV_CONFIG_FILE);
        configuration = WavsMockDeploymentLib.loadConfiguration(configFile);
    }

    function run() external {
        vm.startBroadcast();
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        // deploy middleware contracts
        console2.log("Deploying contracts...");
        deployment = WavsMockDeploymentLib.deployContracts(proxyAdmin);

        // initialize the operator set
        console2.log("Configuring initial state...");
        WavsMockDeploymentLib.setInitialConfiguration(deployment, configuration);

        vm.stopBroadcast();

        verifyDeployment();
        WavsMockDeploymentLib.writeDeploymentJson(deployment);
    }

    function verifyDeployment() internal view {
        if (deployment.stakeRegistry == address(0)) {
            revert WavsMockDeployer__StakeRegistryAddressCannotBeZero();
        }
        if (deployment.wavsServiceManager == address(0)) {
            revert WavsMockDeployer__WavsServiceManagerAddressCannotBeZero();
        }
        if (proxyAdmin == address(0)) {
            revert WavsMockDeployer__ProxyAdminAddressCannotBeZero();
        }
    }
}
