// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {WavsMirrorDeploymentLib} from "./utils/WavsMirrorDeploymentLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";
import {WavsListOperatorsLib} from "./utils/WavsListOperatorsLib.sol";

/**
 * @title WavsMirrorDeployer
 * @author Lay3rLabs
 * @notice This script deploys the WAVS mirror contracts.
 * @dev This script is used to deploy the WAVS mirror contracts.
 */
contract WavsMirrorDeployer is Script {
    using UpgradeableProxyLib for address;

    string private constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";
    string private constant ENV_SOURCE_RPC_URL = "SOURCE_RPC_URL";
    string private constant ENV_MIRROR_RPC_URL = "MIRROR_RPC_URL";

    WavsListOperatorsLib.ConfigData private configData;
    string private sourceRpcUrl;
    string private mirrorRpcUrl;
    address private _serviceManager;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        _serviceManager = vm.envAddress(ENV_SERVICE_MANAGER);
        sourceRpcUrl = vm.envString(ENV_SOURCE_RPC_URL);
        mirrorRpcUrl = vm.envString(ENV_MIRROR_RPC_URL);
    }

    /// @notice The run function for the script.
    function run() external {
        vm.createSelectFork(sourceRpcUrl);
        address[] memory operators = WavsListOperatorsLib.getOperators(_serviceManager, uint8(0));
        configData = WavsListOperatorsLib.getConfigData(_serviceManager, uint8(0), operators);
        vm.createSelectFork(mirrorRpcUrl);

        vm.startBroadcast();
        address proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        // first deploy (from eigenlayer)
        WavsMirrorDeploymentLib.DeploymentData memory wavsMirrorDeployment =
            WavsMirrorDeploymentLib.deployContracts(proxyAdmin);

        // WAVS configuration
        WavsMirrorDeploymentLib.configureContracts(wavsMirrorDeployment, configData);
        vm.stopBroadcast();

        WavsMirrorDeploymentLib.writeDeploymentJson(wavsMirrorDeployment);
    }
}
