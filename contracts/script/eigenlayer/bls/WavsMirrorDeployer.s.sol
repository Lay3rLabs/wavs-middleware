// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {IStakeRegistryTypes} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";

import {WavsMirrorDeploymentLib} from "./utils/WavsMirrorDeploymentLib.sol";
import {WavsMiddlewareDeploymentLib} from "./utils/WavsMiddlewareDeploymentLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";

/**
 * @title WavsMirrorDeployer
 * @author Lay3rLabs
 * @notice This script deploys the WAVS mirror contracts.
 * @dev This script is used to deploy the WAVS mirror contracts.
 */
contract WavsMirrorDeployer is Script {
    using UpgradeableProxyLib for address;

    /// @notice The proxy admin address.
    address public proxyAdmin;
    /// @notice The WAVS mirror deployment data.
    WavsMirrorDeploymentLib.DeploymentData public wavsMirrorDeployment;
    /// @notice The strategy parameters.
    IStakeRegistryTypes.StrategyParams[] public strategyParams;
    /// @notice The minimum weight.
    uint96 public minimumWeight;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        string memory fileName = string.concat("deployments/bls-list-operators.json");
        strategyParams = WavsMiddlewareDeploymentLib.readStrategyParamsConfig(fileName);
        minimumWeight = 100;
    }

    /// @notice The run function for the script.
    function run() external {
        vm.startBroadcast();
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        // first deploy (from eigenlayer)
        wavsMirrorDeployment = WavsMirrorDeploymentLib.deployContracts(proxyAdmin);

        // WAVS configuration
        uint32 lookAheadPeriod = 0;
        WavsMirrorDeploymentLib.configureContracts(
            wavsMirrorDeployment, strategyParams, minimumWeight, lookAheadPeriod
        );
        uint32[] memory opSetIds = new uint32[](1);
        opSetIds[0] = 0;

        // for (uint256 i = 0; i < operators.length; i++) {
        //     MirrorSlashingRegistryCoordinator(wavsMirrorDeployment.slashingRegistryCoordinator)
        //         .registerOperatorForMirror(
        //         operators[i], wavsMirrorDeployment.wavsServiceManager, opSetIds, ""
        //     );
        // }

        vm.stopBroadcast();

        WavsMirrorDeploymentLib.writeDeploymentJson(wavsMirrorDeployment);
    }
}
