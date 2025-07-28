// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";

import {WavsMockDeploymentLib} from "./utils/WavsMockDeploymentLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";

/**
 * @title WavsMockDeployer
 * @author Lay3rLabs
 * @notice This script deploys the WavsMock contracts.
 * @dev This script is used to deploy the WavsMock contracts.
 */
contract WavsMockDeployer is Script {
    using UpgradeableProxyLib for address;

    /// @notice The deployment file name.
    string public constant ENV_DEPLOY_FILE_MOCK = "DEPLOY_FILE_MOCK";

    /// @notice The proxy admin address.
    address public proxyAdmin;
    /// @notice The deployment data.
    WavsMockDeploymentLib.DeploymentData public deployment;

    /// @notice The error for the stake registry address cannot be zero.
    error WavsMockDeployer__StakeRegistryAddressCannotBeZero();
    /// @notice The error for the WAVS service manager address cannot be zero.
    error WavsMockDeployer__WavsServiceManagerAddressCannotBeZero();
    /// @notice The error for the proxy admin address cannot be zero.
    error WavsMockDeployer__ProxyAdminAddressCannotBeZero();

    /// @notice The setup function for the script.
    function setUp() public virtual {}

    /// @notice The run function for the script.
    function run() external {
        vm.startBroadcast();
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        // deploy middleware contracts
        console2.log("Deploying contracts...");
        deployment = WavsMockDeploymentLib.deployContracts(proxyAdmin);

        vm.stopBroadcast();

        verifyDeployment();

        string memory deployFile = vm.envString(ENV_DEPLOY_FILE_MOCK);
        WavsMockDeploymentLib.writeDeploymentJson(deployment, deployFile);
    }

    /// @notice The verify deployment function.
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
