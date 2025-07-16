// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {IAllocationManagerTypes} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {
    IECDSAStakeRegistryTypes,
    IStrategy
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";
import {WavsServiceManager} from "src/eigenlayer/ecdsa/WavsServiceManager.sol";
import {ReadCoreLib} from "./ReadCoreLib.sol";
import {WavsAVSRegistrar} from "src/eigenlayer/ecdsa/WavsAVSRegistrar.sol";

library WavsMiddlewareDeploymentLib {
    using stdJson for *;
    using Strings for *;
    using UpgradeableProxyLib for address;

    struct DeploymentData {
        address wavsServiceManager;
        address stakeRegistry;
        address strategy;
        address avsRegistrar;
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

    function deployContracts(
        address proxyAdmin,
        ReadCoreLib.DeploymentData memory core,
        IECDSAStakeRegistryTypes.Quorum memory quorum
    ) internal returns (DeploymentData memory) {
        DeploymentData memory result;

        // First, deploy upgradeable proxy contracts that will point to the implementations.
        result.wavsServiceManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.stakeRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        // Deploy the implementation contracts, using the proxy contracts as inputs
        address stakeRegistryImpl =
            address(new ECDSAStakeRegistry(IDelegationManager(core.delegationManager)));
        address wavsServiceManagerImpl = address(
            new WavsServiceManager(
                core.avsDirectory,
                result.stakeRegistry,
                core.rewardsCoordinator,
                core.delegationManager,
                core.allocationManager
            )
        );
        // Upgrade contracts
        bytes memory stakeRegistryUpgradeCall = abi.encodeCall(
            ECDSAStakeRegistry.initialize,
            (result.wavsServiceManager, 100, quorum) // TODO: dynamically update threshold (?)
        );
        bytes memory wavsServiceManagerUpgradeCall =
            abi.encodeCall(WavsServiceManager.initialize, (msg.sender, msg.sender));
        UpgradeableProxyLib.upgradeAndCall(
            result.stakeRegistry, stakeRegistryImpl, stakeRegistryUpgradeCall
        );
        UpgradeableProxyLib.upgradeAndCall(
            result.wavsServiceManager, wavsServiceManagerImpl, wavsServiceManagerUpgradeCall
        );

        // TODO: This is incredibly stupid,
        // when we implement out own stake registry, pass owner as an argument
        bytes memory stakeRegistryOwnerUpgradeCall =
            abi.encodeCall(Ownable.transferOwnership, (msg.sender));
        UpgradeableProxyLib.upgradeAndCall(
            result.stakeRegistry, stakeRegistryImpl, stakeRegistryOwnerUpgradeCall
        );

        // Dummy AVSRegistrar deployment for now
        address avsRegistrar = address(new WavsAVSRegistrar());
        result.avsRegistrar = avsRegistrar;

        return result;
    }

    function configureContracts(
        DeploymentData memory deployment,
        string memory metadataUri,
        uint256 minimumWeight
    ) internal {
        // update_minimum_weight
        ECDSAStakeRegistry stakeRegistry = ECDSAStakeRegistry(deployment.stakeRegistry);
        stakeRegistry.updateMinimumWeight(minimumWeight, new address[](0));

        // set avs registrar
        WavsServiceManager wavsServiceManager = WavsServiceManager(deployment.wavsServiceManager);
        wavsServiceManager.setAVSRegistrar(WavsAVSRegistrar(deployment.avsRegistrar));

        // set metadata uri on service manager
        wavsServiceManager.updateAVSMetadataURI(metadataUri);

        // create one operator set (for now)
        // TODO: this is from deploy.sh but why are strategies in lstStrategyAddress and quorum different?
        // If op set only allows one strategy, why do we need 12 registered with multipliers in the quorum?
        // Suggestion - use same both for opset and for initialize. But which one (or both)?
        //             ECDSAStakeRegistry.initialize, (result.WavsServiceManager, 100, quorum) // TODO: dynamically update threshold (?)
        IAllocationManagerTypes.CreateSetParams memory opSetParams = IAllocationManagerTypes
            .CreateSetParams({operatorSetId: 0, strategies: new IStrategy[](1)});
        opSetParams.strategies[0] = IStrategy(deployment.strategy);
        IAllocationManagerTypes.CreateSetParams[] memory opSetParamsArray =
            new IAllocationManagerTypes.CreateSetParams[](1);
        opSetParamsArray[0] = opSetParams;
        wavsServiceManager.createOperatorSets(opSetParamsArray);
    }

    function readQuorumConfig(
        string memory fileName
    ) internal returns (IECDSAStakeRegistryTypes.Quorum memory) {
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
        IECDSAStakeRegistryTypes.Quorum memory quorum = IECDSAStakeRegistryTypes.Quorum({
            strategies: new IECDSAStakeRegistryTypes.StrategyParams[](size)
        });
        for (uint256 i; i < size; i++) {
            totalMultiplier += multipliers[i];
            quorum.strategies[i] = IECDSAStakeRegistryTypes.StrategyParams({
                strategy: IStrategy(strategies[i]),
                multiplier: multipliers[i]
            });
        }
        if (totalMultiplier != 10_000) {
            revert WavsMiddlewareDeploymentLib__TotalMultiplierNot10000();
        }

        return quorum;
    }

    function readQuorumConfig(
        string memory directoryPath,
        uint256 chainId
    ) internal returns (IECDSAStakeRegistryTypes.Quorum memory) {
        string memory fileName = string.concat(directoryPath, VM.toString(chainId), ".json");
        return readQuorumConfig(fileName);
    }

    function readDeploymentJson(
        uint256 chainId
    ) internal returns (DeploymentData memory) {
        return readDeploymentJson("deployments/wavs-middleware/", chainId);
    }

    function readDeploymentJson(
        string memory directoryPath,
        uint256 chainId
    ) internal returns (DeploymentData memory) {
        string memory fileName = string.concat(directoryPath, VM.toString(chainId), ".json");

        if (!VM.exists(fileName)) {
            revert WavsMiddlewareDeploymentLib__DeploymentFileNotFound();
        }

        string memory json = VM.readFile(fileName);

        DeploymentData memory data;
        /// TODO: 2 Step for reading deployment json.  Read to the core and the AVS data
        data.wavsServiceManager = json.readAddress(".contracts.wavsServiceManager");
        data.stakeRegistry = json.readAddress(".contracts.stakeRegistry");
        data.strategy = json.readAddress(".contracts.strategy");
        data.avsRegistrar = json.readAddress(".contracts.avsRegistrar");

        return data;
    }

    /// write to default output path
    function writeDeploymentJson(
        DeploymentData memory data
    ) internal {
        writeDeploymentJson("deployments/wavs-middleware/", block.chainid, data);
    }

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
            "\",\"strategy\":\"",
            data.strategy.toHexString(),
            "\",\"avsRegistrar\":\"",
            data.avsRegistrar.toHexString(),
            "\"}"
        );
    }
}
