// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
import {
    IECDSAStakeRegistryTypes
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";

import {WavsMirrorDeploymentLib} from "./utils/WavsMirrorDeploymentLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";

/**
 * @title WavsMirrorDeployer
 * @author Lay3rLabs
 * @notice This script deploys the WavsMirror contracts.
 * @dev This script is used to deploy the WavsMirror contracts.
 */
contract WavsMirrorDeployer is Script, IECDSAStakeRegistryTypes {
    using UpgradeableProxyLib for address;

    /// @notice The proxy admin address.
    address public proxyAdmin;
    /// @notice The deployment data.
    WavsMirrorDeploymentLib.DeploymentData public deployment;
    /// @notice The initial configuration.
    WavsMirrorDeploymentLib.InitialConfiguration public configuration;

    /// @notice The error for the stake registry address cannot be zero.
    error WavsMirrorDeployer__StakeRegistryAddressCannotBeZero();
    /// @notice The error for the WAVS service manager address cannot be zero.
    error WavsMirrorDeployer__WavsServiceManagerAddressCannotBeZero();
    /// @notice The error for the operator sync handler address cannot be zero.
    error WavsMirrorDeployer__OperatorSyncHandlerAddressCannotBeZero();
    /// @notice The error for the quorum sync handler address cannot be zero.
    error WavsMirrorDeployer__QuorumSyncHandlerAddressCannotBeZero();
    /// @notice The error for the proxy admin address cannot be zero.
    error WavsMirrorDeployer__ProxyAdminAddressCannotBeZero();
    /// @notice The error for the no operators.
    error WavsMirrorDeployer__NoOperators();

    /// @notice The setup function for the script.
    function setUp() public virtual {
        // Pass in the configuration as a file, load it
        string memory configFile = "./deployments/wavs-mirror-config.json";
        configuration = WavsMirrorDeploymentLib.loadConfiguration(configFile);
        if (configuration.operators.length == 0) {
            revert WavsMirrorDeployer__NoOperators();
        }
    }

    /// @notice The run function for the script.
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

    /// @notice The verify deployment function.
    function verifyDeployment() internal view {
        if (deployment.stakeRegistry == address(0)) {
            revert WavsMirrorDeployer__StakeRegistryAddressCannotBeZero();
        }
        if (deployment.wavsServiceManager == address(0)) {
            revert WavsMirrorDeployer__WavsServiceManagerAddressCannotBeZero();
        }
        if (deployment.operatorSyncHandler == address(0)) {
            revert WavsMirrorDeployer__OperatorSyncHandlerAddressCannotBeZero();
        }
        if (deployment.quorumSyncHandler == address(0)) {
            revert WavsMirrorDeployer__QuorumSyncHandlerAddressCannotBeZero();
        }
        if (proxyAdmin == address(0)) {
            revert WavsMirrorDeployer__ProxyAdminAddressCannotBeZero();
        }
    }
}
