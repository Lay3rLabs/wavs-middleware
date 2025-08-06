// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IndexRegistry} from "@eigenlayer-middleware/src/IndexRegistry.sol";
import {SocketRegistry} from "@eigenlayer-middleware/src/SocketRegistry.sol";
import {SlashingRegistryCoordinator} from
    "@eigenlayer-middleware/src/SlashingRegistryCoordinator.sol";

import {
    IStakeRegistry,
    IStakeRegistryTypes
} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {IIndexRegistry} from "@eigenlayer-middleware/src/interfaces/IIndexRegistry.sol";
import {ISocketRegistry} from "@eigenlayer-middleware/src/interfaces/ISocketRegistry.sol";
import {
    ISlashingRegistryCoordinator,
    ISlashingRegistryCoordinatorTypes
} from "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";

import {PauserRegistry} from "@eigenlayer/contracts/permissions/PauserRegistry.sol";
import {IPauserRegistry} from "@eigenlayer/contracts/interfaces/IPauserRegistry.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";

import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";
import {WavsServiceManager} from "src/eigenlayer/bls/WavsServiceManager.sol";
import {MirrorStakeRegistry} from "src/eigenlayer/bls/mirror/MirrorStakeRegistry.sol";
import {MirrorSlashingRegistryCoordinator} from
    "src/eigenlayer/bls/mirror/MirrorSlashingRegistryCoordinator.sol";
import {MirrorBLSApkRegistry} from "src/eigenlayer/bls/mirror/MirrorBLSApkRegistry.sol";

/**
 * @title WavsMiddlewareDeploymentLib
 * @author Lay3rLabs
 * @notice This library contains functions for deploying the WAVS middleware contracts.
 * @dev This library is used to deploy the WAVS middleware contracts.
 */
library WavsMirrorDeploymentLib {
    // using stdJson for *;
    using Strings for *;
    using UpgradeableProxyLib for address;

    /**
     * @notice The deployment data struct.
     * @param wavsServiceManager The WAVS service manager address.
     * @param stakeRegistry The stake registry address.
     * @param slashingRegistryCoordinator The mirror slashing registry coordinator address.
     * @param blsApkRegistry The BLS APK registry address.
     * @param indexRegistry The index registry address.
     * @param socketRegistry The socket registry address.
     * @param pauserRegistry The pauser registry address.
     */
    struct DeploymentData {
        address wavsServiceManager;
        address stakeRegistry;
        address slashingRegistryCoordinator;
        address blsApkRegistry;
        address indexRegistry;
        address socketRegistry;
        address pauserRegistry;
    }

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /**
     * @notice The deploy contracts function.
     * @param proxyAdmin The proxy admin address.
     * @return deployment The deployment data.
     */
    function deployContracts(
        address proxyAdmin
    ) internal returns (DeploymentData memory) {
        // First, deploy upgradeable proxy contracts that will point to the implementations.
        address wavsServiceManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address stakeRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address slashingRegistryCoordinator = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address blsApkRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address indexRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address socketRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);

        address[] memory pausers = new address[](1);
        pausers[0] = msg.sender;
        address pauserRegistry = address(new PauserRegistry(pausers, msg.sender));

        address wavsServiceManagerImpl = address(
            new WavsServiceManager(
                address(0),
                address(0),
                slashingRegistryCoordinator,
                stakeRegistry,
                address(0),
                address(0)
            )
        );
        address stakeRegistryImpl = address(
            new MirrorStakeRegistry(
                ISlashingRegistryCoordinator(slashingRegistryCoordinator),
                IDelegationManager(address(0)),
                IAVSDirectory(address(0)),
                IAllocationManager(address(0))
            )
        );
        address slashingRegistryCoordinatorImpl = address(
            new MirrorSlashingRegistryCoordinator(
                IStakeRegistry(stakeRegistry),
                IBLSApkRegistry(blsApkRegistry),
                IIndexRegistry(indexRegistry),
                ISocketRegistry(socketRegistry),
                IAllocationManager(msg.sender),
                IPauserRegistry(pauserRegistry),
                "1.0.0"
            )
        );

        address blsApkRegistryImpl = address(
            new MirrorBLSApkRegistry(ISlashingRegistryCoordinator(slashingRegistryCoordinator))
        );
        address indexRegistryImpl =
            address(new IndexRegistry(ISlashingRegistryCoordinator(slashingRegistryCoordinator)));
        address socketRegistryImpl =
            address(new SocketRegistry(ISlashingRegistryCoordinator(slashingRegistryCoordinator)));

        UpgradeableProxyLib.upgradeAndCall(
            wavsServiceManager,
            wavsServiceManagerImpl,
            abi.encodeCall(WavsServiceManager.initialize, (msg.sender, msg.sender))
        );
        UpgradeableProxyLib.upgrade(stakeRegistry, stakeRegistryImpl);
        UpgradeableProxyLib.upgradeAndCall(
            slashingRegistryCoordinator,
            slashingRegistryCoordinatorImpl,
            abi.encodeCall(
                SlashingRegistryCoordinator.initialize,
                (msg.sender, msg.sender, msg.sender, 0, wavsServiceManager)
            )
        );
        UpgradeableProxyLib.upgrade(blsApkRegistry, blsApkRegistryImpl);
        UpgradeableProxyLib.upgrade(indexRegistry, indexRegistryImpl);
        UpgradeableProxyLib.upgrade(socketRegistry, socketRegistryImpl);

        return DeploymentData({
            wavsServiceManager: wavsServiceManager,
            stakeRegistry: stakeRegistry,
            slashingRegistryCoordinator: slashingRegistryCoordinator,
            blsApkRegistry: blsApkRegistry,
            indexRegistry: indexRegistry,
            socketRegistry: socketRegistry,
            pauserRegistry: pauserRegistry
        });
    }

    /**
     * @notice The configure contracts function.
     * @param deployment The deployment data.
     * @param strategyParams The strategy params.
     * @param minimumWeight The minimum weight.
     * @param lookAheadPeriod The look ahead period.
     */
    function configureContracts(
        DeploymentData memory deployment,
        IStakeRegistryTypes.StrategyParams[] memory strategyParams,
        uint96 minimumWeight,
        uint32 lookAheadPeriod
    ) internal {
        ISlashingRegistryCoordinator slashingRegistryCoordinator =
            ISlashingRegistryCoordinator(deployment.slashingRegistryCoordinator);
        slashingRegistryCoordinator.createSlashableStakeQuorum(
            ISlashingRegistryCoordinatorTypes.OperatorSetParam({
                maxOperatorCount: 10_000,
                kickBIPsOfOperatorStake: 10_500,
                kickBIPsOfTotalStake: 100
            }),
            minimumWeight,
            strategyParams,
            lookAheadPeriod
        );
    }

    /**
     * @notice The write deployment JSON function.
     * @param data The deployment data.
     */
    function writeDeploymentJson(
        DeploymentData memory data
    ) internal {
        address proxyAdmin = address(UpgradeableProxyLib.getProxyAdmin(data.wavsServiceManager));

        string memory deploymentData = _generateDeploymentJson(data, proxyAdmin);

        if (!VM.exists("deployments/wavs-bls")) {
            VM.createDir("deployments/wavs-bls", true);
        }

        VM.writeFile("deployments/wavs-bls/mirror.json", deploymentData);
        console2.log("Deployment artifacts written to: deployments/wavs-bls/mirror.json");
    }

    /**
     * @notice The generate deployment JSON function.
     * @param data The deployment data.
     * @param proxyAdmin The proxy admin address.
     * @return deploymentData The deployment JSON.
     */
    function _generateDeploymentJson(
        DeploymentData memory data,
        address proxyAdmin
    ) private view returns (string memory) {
        return string.concat(
            "{",
            "\"lastUpdate\":{",
            "\"timestamp\":\"",
            VM.toString(block.timestamp),
            "\",",
            "\"block_number\":\"",
            VM.toString(block.number),
            "\"",
            "},",
            "\"addresses\":",
            _generateContractsJson(data, proxyAdmin),
            "}"
        );
    }

    /**
     * @notice The generate contracts JSON function.
     * @param data The deployment data.
     * @param proxyAdmin The proxy admin address.
     * @return contractsJson The contracts JSON.
     */
    function _generateContractsJson(
        DeploymentData memory data,
        address proxyAdmin
    ) private view returns (string memory) {
        return string.concat(
            "{\"proxyAdmin\":\"",
            proxyAdmin.toHexString(),
            "\",\"WavsServiceManager\":\"",
            data.wavsServiceManager.toHexString(),
            "\",\"WavsServiceManagerImpl\":\"",
            data.wavsServiceManager.getImplementation().toHexString(),
            "\",\"stakeRegistry\":\"",
            data.stakeRegistry.toHexString(),
            "\",\"stakeRegistryImpl\":\"",
            data.stakeRegistry.getImplementation().toHexString(),
            "\",\"slashingRegistryCoordinator\":\"",
            data.slashingRegistryCoordinator.toHexString(),
            "\",\"slashingRegistryCoordinatorImpl\":\"",
            data.slashingRegistryCoordinator.getImplementation().toHexString(),
            "\",\"blsApkRegistry\":\"",
            data.blsApkRegistry.toHexString(),
            "\",\"blsApkRegistryImpl\":\"",
            data.blsApkRegistry.getImplementation().toHexString(),
            "\",\"indexRegistry\":\"",
            data.indexRegistry.toHexString(),
            "\",\"indexRegistryImpl\":\"",
            data.indexRegistry.getImplementation().toHexString(),
            "\",\"socketRegistry\":\"",
            data.socketRegistry.toHexString(),
            "\",\"socketRegistryImpl\":\"",
            data.socketRegistry.getImplementation().toHexString(),
            "\",\"pauserRegistry\":\"",
            data.pauserRegistry.toHexString(),
            "\"}"
        );
    }
}
