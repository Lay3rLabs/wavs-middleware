// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
import {IECDSAStakeRegistryTypes} from
    "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";

import {WavsMirrorDeploymentLib} from "./utils/WavsMirrorDeploymentLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";

contract WavsMirrorDeployer is Script, IECDSAStakeRegistryTypes {
    using UpgradeableProxyLib for address;

    address public proxyAdmin;
    WavsMirrorDeploymentLib.DeploymentData public deployment;
    WavsMirrorDeploymentLib.InitialConfiguration public configuration;

    error WavsMirrorDeployer__StakeRegistryAddressCannotBeZero();
    error WavsMirrorDeployer__WavsServiceManagerAddressCannotBeZero();
    error WavsMirrorDeployer__MirrorServiceHandlerAddressCannotBeZero();
    error WavsMirrorDeployer__MirrorServiceManagerHandlerAddressCannotBeZero();
    error WavsMirrorDeployer__ProxyAdminAddressCannotBeZero();

    function setUp() public virtual {
        // Pass in the configuration as a file, load it
        string memory configFile = "./deployments/wavs-mirror-config.json";
        configuration = WavsMirrorDeploymentLib.loadConfiguration(configFile);
    }

    function run() external {
        vm.startBroadcast();
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        // deploy middleware contracts
        console2.log("Deploying contracts...");
        deployment = WavsMirrorDeploymentLib.deployContracts(proxyAdmin);

        // initialize the operator set
        console2.log("Configuring initial state...");
        WavsMirrorDeploymentLib.setInitialConfiguration(deployment, configuration);

        // deploy the handlers
        console2.log("Deploying ServiceHandlers as admin...");
        deployment = WavsMirrorDeploymentLib.deployServiceHandlers(deployment);

        vm.stopBroadcast();

        verifyDeployment();
        WavsMirrorDeploymentLib.writeDeploymentJson(deployment);
    }

    function verifyDeployment() internal view {
        if (deployment.stakeRegistry == address(0)) {
            revert WavsMirrorDeployer__StakeRegistryAddressCannotBeZero();
        }
        if (deployment.wavsServiceManager == address(0)) {
            revert WavsMirrorDeployer__WavsServiceManagerAddressCannotBeZero();
        }
        if (deployment.mirrorServiceHandler == address(0)) {
            revert WavsMirrorDeployer__MirrorServiceHandlerAddressCannotBeZero();
        }
        if (deployment.mirrorServiceManagerHandler == address(0)) {
            revert WavsMirrorDeployer__MirrorServiceManagerHandlerAddressCannotBeZero();
        }
        if (proxyAdmin == address(0)) {
            revert WavsMirrorDeployer__ProxyAdminAddressCannotBeZero();
        }
    }
}
