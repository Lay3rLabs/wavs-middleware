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

library WavsMiddlewareDeploymentLib {
    // using stdJson for *;
    using Strings for *;
    using UpgradeableProxyLib for address;

    struct DeploymentData {
        address wavsServiceManager;
        address stakeRegistry;
        address registryCoordinator;
        address blsApkRegistry;
        address indexRegistry;
        address socketRegistry;
        address pauserRegistry;
    }

    struct StrategyConfig {
        address strategy;
        uint96 multiplier;
    }

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    error WavsMiddlewareDeploymentLib__StrategiesFileNotFound();
    error WavsMiddlewareDeploymentLib__DeploymentFileNotFound();
    error WavsMiddlewareDeploymentLib__StrategiesAndMultipliersLengthMismatch();
    error WavsMiddlewareDeploymentLib__TotalMultiplierNot10000();
    error WavsMiddlewareDeploymentLib__AVSDirectoryMismatch();

    function deployContracts(
        address proxyAdmin,
        ReadCoreLib.DeploymentData memory core
    ) internal returns (DeploymentData memory) {
        // First, deploy upgradeable proxy contracts that will point to the implementations.
        address wavsServiceManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address stakeRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address registryCoordinator = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address blsApkRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address indexRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        address socketRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);

        address[] memory pausers = new address[](1);
        pausers[0] = msg.sender;
        address pauserRegistry = address(new PauserRegistry(pausers, msg.sender));

        address wavsServiceManagerImpl = address(
            new WavsServiceManager(
                core.avsDirectory,
                core.rewardsCoordinator,
                registryCoordinator,
                stakeRegistry,
                core.permissionController,
                core.allocationManager
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

        return DeploymentData({
            wavsServiceManager: wavsServiceManager,
            stakeRegistry: stakeRegistry,
            registryCoordinator: registryCoordinator,
            blsApkRegistry: blsApkRegistry,
            indexRegistry: indexRegistry,
            socketRegistry: socketRegistry,
            pauserRegistry: pauserRegistry
        });
    }

    function configureContracts(
        DeploymentData memory deployment,
        IStakeRegistryTypes.StrategyParams[] memory strategyParams,
        string memory metadataUri,
        address allocationManagerAddress,
        address permissionControllerAddress,
        uint96 minimumWeight
    ) internal {
        // set avs registrar
        WavsServiceManager wavsServiceManager = WavsServiceManager(deployment.wavsServiceManager);
        wavsServiceManager.setAppointee(
            deployment.registryCoordinator,
            allocationManagerAddress,
            bytes4(keccak256("createOperatorSets(address,(uint32,address[])[])"))
        );

        wavsServiceManager.updateAVSMetadataURI(metadataUri);

        ISlashingRegistryCoordinator slashingRegistryCoordinator =
            ISlashingRegistryCoordinator(deployment.registryCoordinator);
        slashingRegistryCoordinator.createTotalDelegatedStakeQuorum(
            ISlashingRegistryCoordinatorTypes.OperatorSetParam({
                maxOperatorCount: 100,
                kickBIPsOfOperatorStake: 10_500,
                kickBIPsOfTotalStake: 100
            }),
            minimumWeight,
            strategyParams
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

    function readStrategyParamsConfig(
        string memory fileName
    ) internal returns (IStakeRegistryTypes.StrategyParams[] memory) {
        if (!VM.exists(fileName)) {
            revert WavsMiddlewareDeploymentLib__StrategiesFileNotFound();
        }

        // load the strategies config
        string memory json = VM.readFile(fileName);
        address[] memory strategies = abi.decode(VM.parseJson(json, ".strategies"), (address[]));
        uint96[] memory multipliers = abi.decode(VM.parseJson(json, ".multipliers"), (uint96[]));
        if (strategies.length != multipliers.length) {
            revert WavsMiddlewareDeploymentLib__StrategiesAndMultipliersLengthMismatch();
        }

        // convert to quorum
        uint256 size = strategies.length;
        uint256 totalMultiplier = 0;
        IStakeRegistryTypes.StrategyParams[] memory strategyParams =
            new IStakeRegistryTypes.StrategyParams[](size);
        for (uint256 i; i < size; i++) {
            totalMultiplier += multipliers[i];
            strategyParams[i] = IStakeRegistryTypes.StrategyParams({
                strategy: IStrategy(strategies[i]),
                multiplier: multipliers[i]
            });
        }
        if (totalMultiplier != 10_000) {
            revert WavsMiddlewareDeploymentLib__TotalMultiplierNot10000();
        }

        return strategyParams;
    }

    // function readDeploymentJson(
    //     string memory directoryPath,
    //     uint256 chainId
    // ) internal returns (DeploymentData memory) {
    //     string memory fileName = string.concat(directoryPath, VM.toString(chainId), ".json");

    //     if (!VM.exists(fileName)) {
    //         revert WavsMiddlewareDeploymentLib__DeploymentFileNotFound();
    //     }

    //     string memory json = VM.readFile(fileName);

    //     DeploymentData memory data;
    //     /// TODO: 2 Step for reading deployment json.  Read to the core and the AVS data
    //     data.wavsServiceManager = json.readAddress(".contracts.wavsServiceManager");
    //     data.stakeRegistry = json.readAddress(".contracts.stakeRegistry");
    //     data.strategy = json.readAddress(".contracts.strategy");
    //     data.avsRegistrar = json.readAddress(".contracts.avsRegistrar");

    //     return data;
    // }

    function writeDeploymentJson(
        string memory outputPath,
        uint256 chainId,
        DeploymentData memory data
    ) internal {
        address proxyAdmin = address(UpgradeableProxyLib.getProxyAdmin(data.wavsServiceManager));

        string memory deploymentData = _generateDeploymentJson(data, proxyAdmin);

        string memory fileName = string.concat(outputPath, VM.toString(chainId), ".json");
        if (!VM.exists(outputPath)) {
            VM.createDir(outputPath, true);
        }

        VM.writeFile(fileName, deploymentData);
        console2.log("Deployment artifacts written to:", fileName);
    }

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
            "\"}"
        );
    }
}
