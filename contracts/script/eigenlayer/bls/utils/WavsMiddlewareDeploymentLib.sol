// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {StakeRegistry} from "@eigenlayer-middleware/src/StakeRegistry.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";
import {IndexRegistry} from "@eigenlayer-middleware/src/IndexRegistry.sol";
import {SocketRegistry} from "@eigenlayer-middleware/src/SocketRegistry.sol";
import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {SlashingRegistryCoordinator} from
    "@eigenlayer-middleware/src/SlashingRegistryCoordinator.sol";
import {InstantSlasher} from "@eigenlayer-middleware/src/slashers/InstantSlasher.sol";
import {OperatorStateRetriever} from "@eigenlayer-middleware/src/OperatorStateRetriever.sol";

import {
    IStakeRegistry,
    IStakeRegistryTypes
} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {IIndexRegistry} from "@eigenlayer-middleware/src/interfaces/IIndexRegistry.sol";
import {ISocketRegistry} from "@eigenlayer-middleware/src/interfaces/ISocketRegistry.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import {IRegistryCoordinatorTypes} from
    "@eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {
    ISlashingRegistryCoordinator,
    ISlashingRegistryCoordinatorTypes
} from "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";

import {PauserRegistry} from "@eigenlayer/contracts/permissions/PauserRegistry.sol";
import {IPauserRegistry} from "@eigenlayer/contracts/interfaces/IPauserRegistry.sol";
import {IPermissionController} from "@eigenlayer/contracts/interfaces/IPermissionController.sol";
import {IAVSRegistrar} from "@eigenlayer/contracts/interfaces/IAVSRegistrar.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {IStrategy} from "@eigenlayer/contracts/interfaces/IStrategy.sol";

import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";
import {ReadCoreLib} from "./ReadCoreLib.sol";
import {WavsServiceManager} from "src/eigenlayer/bls/WavsServiceManager.sol";
import {WavsTaskManager} from "src/eigenlayer/bls/WavsTaskManager.sol";

library WavsMiddlewareDeploymentLib {
    // using stdJson for *;
    using Strings for *;
    using UpgradeableProxyLib for address;

    /**
     * @notice The deployment data struct.
     * @param wavsServiceManager The WAVS service manager address.
     * @param stakeRegistry The stake registry address.
     * @param registryCoordinator The registry coordinator address.
     * @param blsApkRegistry The BLS APK registry address.
     * @param indexRegistry The index registry address.
     * @param socketRegistry The socket registry address.
     * @param pauserRegistry The pauser registry address.
     */
    struct DeploymentData {
        address wavsServiceManager;
        address wavsTaskManager;
        address stakeRegistry;
        address registryCoordinator;
        address blsApkRegistry;
        address indexRegistry;
        address socketRegistry;
        address pauserRegistry;
        address slasher;
        address operatorStateRetriever;
    }

    /**
     * @notice The strategy config struct.
     * @param strategy The strategy address.
     * @param multiplier The multiplier.
     */
    struct StrategyConfig {
        address strategy;
        uint96 multiplier;
    }

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice The error for the strategies file not found.
    error WavsMiddlewareDeploymentLib__StrategiesFileNotFound();
    /// @notice The error for the deployment file not found.
    error WavsMiddlewareDeploymentLib__DeploymentFileNotFound();
    error WavsMiddlewareDeploymentLib__AVSDirectoryMismatch();

    /**
     * @notice The deploy contracts function.
     * @param proxyAdmin The proxy admin address.
     * @param core The core deployment data.
     * @return deployment The deployment data.
     */
    function deployContracts(
        address proxyAdmin,
        ReadCoreLib.DeploymentData memory core
    ) internal returns (DeploymentData memory) {
        // First, deploy upgradeable proxy contracts that will point to the implementations.
        address wavsServiceManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address wavsTaskManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address stakeRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address registryCoordinator = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address blsApkRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address indexRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address socketRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address slasher = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);

        address[] memory pausers = new address[](1);
        pausers[0] = msg.sender;
        address pauserRegistry = address(new PauserRegistry(pausers, msg.sender));
        address operatorStateRetriever = address(new OperatorStateRetriever());

        address wavsServiceManagerImpl = address(
            new WavsServiceManager(
                core.avsDirectory,
                core.rewardsCoordinator,
                registryCoordinator,
                stakeRegistry,
                core.permissionController,
                core.allocationManager,
                wavsTaskManager
            )
        );
        address stakeRegistryImpl = address(
            new StakeRegistry(
                ISlashingRegistryCoordinator(registryCoordinator),
                IDelegationManager(core.delegationManager),
                IAVSDirectory(core.avsDirectory),
                IAllocationManager(core.allocationManager)
            )
        );
        address registryCoordinatorImpl = address(
            new RegistryCoordinator(
                IRegistryCoordinatorTypes.RegistryCoordinatorParams({
                    serviceManager: IServiceManager(wavsServiceManager),
                    slashingParams: IRegistryCoordinatorTypes.SlashingRegistryParams({
                        stakeRegistry: IStakeRegistry(stakeRegistry),
                        blsApkRegistry: IBLSApkRegistry(blsApkRegistry),
                        indexRegistry: IIndexRegistry(indexRegistry),
                        socketRegistry: ISocketRegistry(socketRegistry),
                        allocationManager: IAllocationManager(core.allocationManager),
                        pauserRegistry: IPauserRegistry(pauserRegistry)
                    })
                })
            )
        );

        address blsApkRegistryImpl =
            address(new BLSApkRegistry(ISlashingRegistryCoordinator(registryCoordinator)));
        address indexRegistryImpl =
            address(new IndexRegistry(ISlashingRegistryCoordinator(registryCoordinator)));
        address socketRegistryImpl =
            address(new SocketRegistry(ISlashingRegistryCoordinator(registryCoordinator)));
        address slasherImpl = address(
            new InstantSlasher(
                IAllocationManager(core.allocationManager),
                ISlashingRegistryCoordinator(registryCoordinator),
                wavsTaskManager
            )
        );

        UpgradeableProxyLib.upgradeAndCall(
            wavsServiceManager,
            wavsServiceManagerImpl,
            abi.encodeCall(WavsServiceManager.initialize, (msg.sender, msg.sender))
        );
        UpgradeableProxyLib.upgrade(stakeRegistry, stakeRegistryImpl);
        UpgradeableProxyLib.upgradeAndCall(
            registryCoordinator,
            registryCoordinatorImpl,
            abi.encodeCall(
                SlashingRegistryCoordinator.initialize,
                (msg.sender, msg.sender, msg.sender, 0, wavsServiceManager)
            )
        );
        UpgradeableProxyLib.upgrade(blsApkRegistry, blsApkRegistryImpl);
        UpgradeableProxyLib.upgrade(indexRegistry, indexRegistryImpl);
        UpgradeableProxyLib.upgrade(socketRegistry, socketRegistryImpl);
        UpgradeableProxyLib.upgrade(slasher, slasherImpl);

        address wavsTaskManagerImpl = address(
            new WavsTaskManager(
                ISlashingRegistryCoordinator(registryCoordinator),
                IPauserRegistry(pauserRegistry),
                30
            )
        );
        UpgradeableProxyLib.upgradeAndCall(
            wavsTaskManager,
            wavsTaskManagerImpl,
            abi.encodeCall(
                WavsTaskManager.initialize,
                (
                    msg.sender,
                    msg.sender,
                    msg.sender,
                    core.allocationManager,
                    slasher,
                    wavsServiceManager
                )
            )
        );

        return DeploymentData({
            wavsServiceManager: wavsServiceManager,
            wavsTaskManager: wavsTaskManager,
            stakeRegistry: stakeRegistry,
            registryCoordinator: registryCoordinator,
            blsApkRegistry: blsApkRegistry,
            indexRegistry: indexRegistry,
            socketRegistry: socketRegistry,
            pauserRegistry: pauserRegistry,
            slasher: slasher,
            operatorStateRetriever: operatorStateRetriever
        });
    }

    /**
     * @notice The configure contracts function.
     * @param deployment The deployment data.
     * @param strategyParams The strategy params.
     * @param metadataUri The metadata URI.
     * @param allocationManagerAddress The allocation manager address.
     * @param permissionControllerAddress The permission controller address.
     * @param minimumWeight The minimum weight.
     * @param lookAheadPeriod The look ahead period.
     */
    function configureContracts(
        DeploymentData memory deployment,
        IStakeRegistryTypes.StrategyParams[] memory strategyParams,
        string memory metadataUri,
        address allocationManagerAddress,
        address permissionControllerAddress,
        uint96 minimumWeight,
        uint32 lookAheadPeriod
    ) internal {
        // set avs registrar
        WavsServiceManager wavsServiceManager = WavsServiceManager(deployment.wavsServiceManager);
        wavsServiceManager.setAppointee(
            deployment.registryCoordinator,
            allocationManagerAddress,
            IAllocationManager.createOperatorSets.selector
        );

        wavsServiceManager.updateAVSMetadataURI(metadataUri);

        ISlashingRegistryCoordinator slashingRegistryCoordinator =
            ISlashingRegistryCoordinator(deployment.registryCoordinator);
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

        wavsServiceManager.addPendingAdmin(msg.sender);
        IPermissionController permissionController =
            IPermissionController(permissionControllerAddress);
        permissionController.acceptAdmin(deployment.wavsServiceManager);

        IAllocationManager allocationManager = IAllocationManager(allocationManagerAddress);
        allocationManager.setAVSRegistrar(
            deployment.wavsServiceManager, IAVSRegistrar(deployment.registryCoordinator)
        );
    }

    /**
     * @notice The read strategy params config function.
     * @param fileName The file name.
     * @return strategyParams The strategy params.
     */
    function readStrategyParamsConfig(
        string memory fileName
    ) internal returns (IStakeRegistryTypes.StrategyParams[] memory) {
        if (!VM.exists(fileName)) {
            revert WavsMiddlewareDeploymentLib__StrategiesFileNotFound();
        }

        // load the strategies config
        string memory json = VM.readFile(fileName);
        address[] memory strategies = abi.decode(VM.parseJson(json, ".strategies"), (address[]));
        uint256 strategyCount = strategies.length;
        uint96[] memory multipliers = new uint96[](strategyCount);
        for (uint256 i; i < strategyCount; i++) {
            multipliers[i] = 1 ether;
        }

        // convert to quorum
        IStakeRegistryTypes.StrategyParams[] memory strategyParams =
            new IStakeRegistryTypes.StrategyParams[](strategyCount);
        for (uint256 i; i < strategyCount; i++) {
            strategyParams[i] = IStakeRegistryTypes.StrategyParams({
                strategy: IStrategy(strategies[i]),
                multiplier: multipliers[i]
            });
        }

        return strategyParams;
    }

    function writeDeploymentJson(
        DeploymentData memory data
    ) internal {
        address proxyAdmin = address(UpgradeableProxyLib.getProxyAdmin(data.wavsServiceManager));

        string memory deploymentData = _generateDeploymentJson(data, proxyAdmin);

        if (!VM.exists("deployments/wavs-bls")) {
            VM.createDir("deployments/wavs-bls", true);
        }

        VM.writeFile("deployments/wavs-bls/avs_deploy.json", deploymentData);
        console2.log("Deployment artifacts written to: deployments/wavs-bls/avs_deploy.json");
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
            "\",\"wavsTaskManager\":\"",
            data.wavsTaskManager.toHexString(),
            "\",\"wavsTaskManagerImpl\":\"",
            data.wavsTaskManager.getImplementation().toHexString(),
            "\",\"stakeRegistry\":\"",
            data.stakeRegistry.toHexString(),
            "\",\"stakeRegistryImpl\":\"",
            data.stakeRegistry.getImplementation().toHexString(),
            "\",\"registryCoordinator\":\"",
            data.registryCoordinator.toHexString(),
            "\",\"registryCoordinatorImpl\":\"",
            data.registryCoordinator.getImplementation().toHexString(),
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
            "\",\"slasher\":\"",
            data.slasher.toHexString(),
            "\",\"slasherImpl\":\"",
            data.slasher.getImplementation().toHexString(),
            "\",\"operatorStateRetriever\":\"",
            data.operatorStateRetriever.toHexString(),
            "\"}"
        );
    }
}
