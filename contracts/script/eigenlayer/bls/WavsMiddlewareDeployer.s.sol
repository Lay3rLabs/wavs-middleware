// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {StakeRegistry} from "@eigenlayer-middleware/src/StakeRegistry.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";
import {IndexRegistry} from "@eigenlayer-middleware/src/IndexRegistry.sol";
import {SocketRegistry} from "@eigenlayer-middleware/src/SocketRegistry.sol";
import {PauserRegistry} from "@eigenlayer/contracts/permissions/PauserRegistry.sol";
import {IStakeRegistryTypes} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {SlashingRegistryCoordinator} from
    "@eigenlayer-middleware/src/SlashingRegistryCoordinator.sol";

import {WavsMiddlewareDeploymentLib} from "./utils/WavsMiddlewareDeploymentLib.sol";
import {WavsServiceManager} from "src/eigenlayer/bls/WavsServiceManager.sol";
import {ReadCoreLib} from "./utils/ReadCoreLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";

/**
 * @title WavsMiddlewareDeployer
 * @author Lay3rLabs
 * @notice This script deploys the WAVS middleware contracts.
 * @dev This script is used to deploy the WAVS middleware contracts.
 */
contract WavsMiddlewareDeployer is Script {
    using UpgradeableProxyLib for address;

    /// @notice The environment variable for the metadata URI.
    string public constant ENV_METADATA_URI = "METADATA_URI";

    /// @notice The metadata URI.
    string private _metadataUri;

    /// @notice The proxy admin address.
    address public proxyAdmin;
    /// @notice The core deployment data.
    ReadCoreLib.DeploymentData public coreDeployment;
    /// @notice The WAVS middleware deployment data.
    WavsMiddlewareDeploymentLib.DeploymentData public wavsMiddlewareDeployment;
    /// @notice The strategy parameters.
    IStakeRegistryTypes.StrategyParams[] public strategyParams;

    /// @notice The error for the WAVS service manager mismatch.
    error WavsMiddlewareDeployer__WavsServiceManagerMismatch();
    /// @notice The error for the stake registry mismatch.
    error WavsMiddlewareDeployer__StakeRegistryMismatch();
    /// @notice The error for the registry coordinator mismatch.
    error WavsMiddlewareDeployer__RegistryCoordinatorMismatch();
    /// @notice The error for the BLS APK registry mismatch.
    error WavsMiddlewareDeployer__BLSApkRegistryMismatch();
    /// @notice The error for the index registry mismatch.
    error WavsMiddlewareDeployer__IndexRegistryMismatch();
    /// @notice The error for the socket registry mismatch.
    error WavsMiddlewareDeployer__SocketRegistryMismatch();
    /// @notice The error for the pauser registry mismatch.
    error WavsMiddlewareDeployer__PauserRegistryMismatch();

    /// @notice The setup function for the script.
    function setUp() public virtual {
        coreDeployment =
            ReadCoreLib.readDeploymentJson("deployments/eigenlayer-core/", block.chainid);

        _metadataUri = vm.envString(ENV_METADATA_URI);

        string memory fileName =
            string.concat("deployments/strategies/", vm.toString(block.chainid), ".json");
        strategyParams = WavsMiddlewareDeploymentLib.readStrategyParamsConfig(fileName);
    }

    /// @notice The run function for the script.
    function run() external {
        vm.startBroadcast();
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        // first deploy (from eigenlayer)
        wavsMiddlewareDeployment =
            WavsMiddlewareDeploymentLib.deployContracts(proxyAdmin, coreDeployment);

        // WAVS configuration
        uint96 minimumWeight = 100;
        uint32 lookAheadPeriod = 0;
        WavsMiddlewareDeploymentLib.configureContracts(
            wavsMiddlewareDeployment,
            strategyParams,
            _metadataUri,
            coreDeployment.allocationManager,
            coreDeployment.permissionController,
            minimumWeight,
            lookAheadPeriod
        );

        vm.stopBroadcast();

        _verifyDeployment();
        WavsMiddlewareDeploymentLib.writeDeploymentJson(wavsMiddlewareDeployment);
    }

    /// @notice The verify deployment function.
    function _verifyDeployment() internal view {
        WavsServiceManager wavsServiceManager =
            WavsServiceManager(wavsMiddlewareDeployment.wavsServiceManager);
        StakeRegistry stakeRegistry = StakeRegistry(wavsMiddlewareDeployment.stakeRegistry);
        SlashingRegistryCoordinator registryCoordinator =
            SlashingRegistryCoordinator(wavsMiddlewareDeployment.registryCoordinator);
        BLSApkRegistry blsApkRegistry = BLSApkRegistry(wavsMiddlewareDeployment.blsApkRegistry);
        IndexRegistry indexRegistry = IndexRegistry(wavsMiddlewareDeployment.indexRegistry);
        SocketRegistry socketRegistry = SocketRegistry(wavsMiddlewareDeployment.socketRegistry);
        PauserRegistry pauserRegistry = PauserRegistry(wavsMiddlewareDeployment.pauserRegistry);

        if (wavsServiceManager.avsDirectory() != coreDeployment.avsDirectory) {
            revert WavsMiddlewareDeployer__WavsServiceManagerMismatch();
        }
        if (
            address(stakeRegistry.delegation()) != coreDeployment.delegationManager
                || address(stakeRegistry.avsDirectory()) != coreDeployment.avsDirectory
                || address(stakeRegistry.allocationManager()) != coreDeployment.allocationManager
                || address(stakeRegistry.registryCoordinator())
                    != wavsMiddlewareDeployment.registryCoordinator
        ) {
            revert WavsMiddlewareDeployer__StakeRegistryMismatch();
        }
        if (
            address(registryCoordinator.stakeRegistry()) != wavsMiddlewareDeployment.stakeRegistry
                || address(registryCoordinator.blsApkRegistry())
                    != wavsMiddlewareDeployment.blsApkRegistry
                || address(registryCoordinator.indexRegistry())
                    != wavsMiddlewareDeployment.indexRegistry
                || address(registryCoordinator.socketRegistry())
                    != wavsMiddlewareDeployment.socketRegistry
                || address(registryCoordinator.allocationManager()) != coreDeployment.allocationManager
                || address(registryCoordinator.pauserRegistry())
                    != wavsMiddlewareDeployment.pauserRegistry
        ) {
            revert WavsMiddlewareDeployer__RegistryCoordinatorMismatch();
        }
        if (blsApkRegistry.registryCoordinator() != wavsMiddlewareDeployment.registryCoordinator) {
            revert WavsMiddlewareDeployer__BLSApkRegistryMismatch();
        }
        if (indexRegistry.registryCoordinator() != wavsMiddlewareDeployment.registryCoordinator) {
            revert WavsMiddlewareDeployer__IndexRegistryMismatch();
        }
        if (
            socketRegistry.slashingRegistryCoordinator()
                != wavsMiddlewareDeployment.registryCoordinator
        ) {
            revert WavsMiddlewareDeployer__SocketRegistryMismatch();
        }
        if (
            wavsMiddlewareDeployment.pauserRegistry == address(0)
                || pauserRegistry.unpauser() != msg.sender
                || pauserRegistry.isPauser(msg.sender) == false
        ) {
            revert WavsMiddlewareDeployer__PauserRegistryMismatch();
        }
    }
}
