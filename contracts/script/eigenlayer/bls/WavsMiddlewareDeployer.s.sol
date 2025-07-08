// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {StakeRegistry} from "@eigenlayer-middleware/src/StakeRegistry.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";
import {IndexRegistry} from "@eigenlayer-middleware/src/IndexRegistry.sol";
import {SocketRegistry} from "@eigenlayer-middleware/src/SocketRegistry.sol";
import {PauserRegistry} from "@eigenlayer/contracts/permissions/PauserRegistry.sol";
import {IStakeRegistryTypes} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";

import {WavsMiddlewareDeploymentLib} from "./utils/WavsMiddlewareDeploymentLib.sol";
import {WavsServiceManager} from "src/eigenlayer/bls/WavsServiceManager.sol";
import {ReadCoreLib} from "./utils/ReadCoreLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";

contract WavsMiddlewareDeployer is Script {
    using UpgradeableProxyLib for address;

    // Environment variables for configureContracts
    string public constant ENV_METADATA_URI = "METADATA_URI";

    // Deployment configuration
    string private _metadataUri;

    address public proxyAdmin;
    ReadCoreLib.DeploymentData public coreDeployment;
    WavsMiddlewareDeploymentLib.DeploymentData public wavsMiddlewareDeployment;
    IStakeRegistryTypes.StrategyParams[] public strategyParams;

    error WavsMiddlewareDeployer__WavsServiceManagerMismatch();
    error WavsMiddlewareDeployer__StakeRegistryMismatch();
    error WavsMiddlewareDeployer__RegistryCoordinatorMismatch();
    error WavsMiddlewareDeployer__BLSApkRegistryMismatch();
    error WavsMiddlewareDeployer__IndexRegistryMismatch();
    error WavsMiddlewareDeployer__SocketRegistryMismatch();
    error WavsMiddlewareDeployer__PauserRegistryMismatch();

    function setUp() public virtual {
        coreDeployment =
            ReadCoreLib.readDeploymentJson("deployments/eigenlayer-core/", block.chainid);

        _metadataUri = vm.envString(ENV_METADATA_URI);

        string memory fileName =
            string.concat("deployments/strategies/", vm.toString(block.chainid), ".json");
        strategyParams = WavsMiddlewareDeploymentLib.readStrategyParamsConfig(fileName);
    }

    function run() external {
        vm.startBroadcast();
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        // first deploy (from eigenlayer)
        wavsMiddlewareDeployment =
            WavsMiddlewareDeploymentLib.deployContracts(proxyAdmin, coreDeployment);

        // WAVS configuration
        uint96 minimumWeight = 100;
        WavsMiddlewareDeploymentLib.configureContracts(
            wavsMiddlewareDeployment,
            strategyParams,
            _metadataUri,
            coreDeployment.allocationManager,
            coreDeployment.permissionController,
            minimumWeight
        );

        vm.stopBroadcast();

        _verifyDeployment();
        WavsMiddlewareDeploymentLib.writeDeploymentJson(
            "deployments/wavs-middleware/", block.chainid, wavsMiddlewareDeployment
        );
    }

    function _verifyDeployment() internal view {
        WavsServiceManager wavsServiceManager =
            WavsServiceManager(wavsMiddlewareDeployment.wavsServiceManager);
        StakeRegistry stakeRegistry = StakeRegistry(wavsMiddlewareDeployment.stakeRegistry);
        RegistryCoordinator registryCoordinator =
            RegistryCoordinator(wavsMiddlewareDeployment.registryCoordinator);
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
            address(registryCoordinator.serviceManager())
                != wavsMiddlewareDeployment.wavsServiceManager
                || address(registryCoordinator.stakeRegistry())
                    != wavsMiddlewareDeployment.stakeRegistry
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
