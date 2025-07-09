// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {OperatorSet} from "@eigenlayer/contracts/libraries/OperatorSetLib.sol";
import {
    IECDSAStakeRegistryTypes,
    IStrategy
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {MirrorStakeRegistry} from "src/eigenlayer/ecdsa/MirrorStakeRegistry.sol";
import {MirrorServiceHandler} from "src/eigenlayer/ecdsa/handlers/MirrorServiceHandler.sol";
import {MirrorServiceManagerHandler} from
    "src/eigenlayer/ecdsa/handlers/MirrorServiceManagerHandler.sol";
import {WavsServiceManager} from "src/eigenlayer/ecdsa/WavsServiceManager.sol";
import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";

library WavsMirrorDeploymentLib {
    using stdJson for *;
    using Strings for *;
    using UpgradeableProxyLib for address;

    struct InitialConfiguration {
        // original operators
        address[] operators;
        address[] signingKeyAddresses;
        uint256[] weights;
        // stake registry threshold
        uint256 thresholdWeight;
        // service manager threshold
        uint256 quorumNumerator;
        uint256 quorumDenominator;
    }

    struct DeploymentData {
        address wavsServiceManager;
        address stakeRegistry;
        address mirrorServiceHandler;
        address mirrorServiceManagerHandler;
    }

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    error WavsMirrorDeploymentLib__ConfigFileNotFound();
    error WavsMirrorDeploymentLib__DeploymentFileNotFound();
    error WavsMirrorDeploymentLib__OperatorsAndSigningKeysLengthMismatch();
    error WavsMirrorDeploymentLib__OperatorsAndWeightsLengthMismatch();
    error WavsMirrorDeploymentLib__ServiceHandlersAlreadyDeployed();

    function deployContracts(
        address proxyAdmin
    ) internal returns (DeploymentData memory) {
        DeploymentData memory result;

        // FIXME: remove debug
        // (, address msgSender, address txOrigin) = vm.readCallers();
        // console2.log("deployContracts");
        // console2.log("msgSender", msgSender);
        // console2.log("txOrigin", txOrigin);
        // console2.log("msg.sender", msg.sender);

        // use an mock quorum so checks pass, we don't use it internally
        IStrategy mockStrategyInstance = IStrategy(address(1)); // Using address(1) instead of address(0)
        IECDSAStakeRegistryTypes.StrategyParams memory strategyParams = IECDSAStakeRegistryTypes
            .StrategyParams({
            strategy: mockStrategyInstance,
            multiplier: 10_000 // 100% in basis points
        });
        IECDSAStakeRegistryTypes.StrategyParams[] memory strategies =
            new IECDSAStakeRegistryTypes.StrategyParams[](1);
        strategies[0] = strategyParams;
        IECDSAStakeRegistryTypes.Quorum memory quorum =
            IECDSAStakeRegistryTypes.Quorum({strategies: strategies});

        // First, deploy upgradeable proxy contracts that will point to the implementations.
        result.wavsServiceManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.stakeRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        // Deploy the implementation contracts, using the proxy contracts as inputs
        address stakeRegistryImpl = address(new MirrorStakeRegistry());
        // Use 0 address for contracts we don't use
        address wavsServiceManagerImpl = address(
            new WavsServiceManager(
                address(0), result.stakeRegistry, address(0), address(0), address(0)
            )
        );
        // Upgrade contracts
        bytes memory stakeRegistryUpgradeCall = abi.encodeCall(
            MirrorStakeRegistry.initialize,
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

        return result;
    }

    function setInitialConfiguration(
        DeploymentData memory deployment,
        InitialConfiguration memory configuration
    ) internal {
        MirrorStakeRegistry stakeRegistry = MirrorStakeRegistry(deployment.stakeRegistry);
        WavsServiceManager serviceManager = WavsServiceManager(deployment.wavsServiceManager);

        // // FIXME: remove debug
        // console2.log("owners");
        // console2.log(stakeRegistry.owner());
        // console2.log(serviceManager.owner());

        // TODO: fails here on broadcast, no error message. removing as unused in README.md
        // stakeRegistry.updateStakeThreshold(configuration.thresholdWeight);
        stakeRegistry.batchSetOperatorDetails(
            configuration.operators, configuration.signingKeyAddresses, configuration.weights
        );
        serviceManager.setQuorumThreshold(
            configuration.quorumNumerator, configuration.quorumDenominator
        );
    }

    // deploy service handlers to run mirroring and transfer ownership
    // must be called by the owner of the service manager
    function deployServiceHandlers(
        DeploymentData memory deployment
    ) internal returns (DeploymentData memory) {
        if (
            deployment.mirrorServiceHandler != address(0)
                || deployment.mirrorServiceManagerHandler != address(0)
        ) {
            revert WavsMirrorDeploymentLib__ServiceHandlersAlreadyDeployed();
        }

        DeploymentData memory result = deployment;

        // deploy the stake registry handler
        MirrorStakeRegistry stakeRegistry = MirrorStakeRegistry(result.stakeRegistry);
        result.mirrorServiceHandler = address(new MirrorServiceHandler(stakeRegistry));
        stakeRegistry.transferOwnership(result.mirrorServiceHandler);

        // deploy the service manager handler
        WavsServiceManager serviceManager = WavsServiceManager(result.wavsServiceManager);
        result.mirrorServiceManagerHandler =
            address(new MirrorServiceManagerHandler(serviceManager));
        serviceManager.transferOwnership(result.mirrorServiceManagerHandler);

        return result;
    }

    function loadConfiguration(
        string memory filePath
    ) internal returns (WavsMirrorDeploymentLib.InitialConfiguration memory) {
        // load the config
        if (!VM.exists(filePath)) {
            revert WavsMirrorDeploymentLib__ConfigFileNotFound();
        }
        string memory json = VM.readFile(filePath);

        // parse it
        WavsMirrorDeploymentLib.InitialConfiguration memory cfg;
        cfg.operators = abi.decode(VM.parseJson(json, ".operators"), (address[]));
        cfg.signingKeyAddresses =
            abi.decode(VM.parseJson(json, ".signingKeyAddresses"), (address[]));
        cfg.weights = abi.decode(VM.parseJson(json, ".weights"), (uint256[]));
        if (cfg.operators.length != cfg.signingKeyAddresses.length) {
            revert WavsMirrorDeploymentLib__OperatorsAndSigningKeysLengthMismatch();
        }
        if (cfg.operators.length != cfg.weights.length) {
            revert WavsMirrorDeploymentLib__OperatorsAndWeightsLengthMismatch();
        }

        cfg.thresholdWeight = abi.decode(VM.parseJson(json, ".threshold"), (uint256));
        cfg.quorumNumerator = abi.decode(VM.parseJson(json, ".quorumNumerator"), (uint256));
        cfg.quorumDenominator = abi.decode(VM.parseJson(json, ".quorumDenominator"), (uint256));
        return cfg;
    }

    function writeConfiguration(
        string memory filePath,
        WavsMirrorDeploymentLib.InitialConfiguration memory config
    ) internal {
        string memory objectKey = "WavsMirrorConfigJson"; // An arbitrary unique key for forge's internal JSON object tracking

        // Serialize each field of the configuration into the JSON buffer
        VM.serializeAddress(objectKey, "operators", config.operators);
        VM.serializeAddress(objectKey, "signingKeyAddresses", config.signingKeyAddresses);
        VM.serializeUint(objectKey, "weights", config.weights);
        VM.serializeUint(objectKey, "threshold", config.thresholdWeight);
        VM.serializeUint(objectKey, "quorumNumerator", config.quorumNumerator);
        string memory jsonOutput =
            VM.serializeUint(objectKey, "quorumDenominator", config.quorumDenominator);

        // Write the composed JSON string to the specified file
        VM.writeFile(filePath, jsonOutput);
    }

    // This should be run on the source chain (with ECDSAStakeRegistry)
    // All other functions should run on mirror chain (with MirrorStakeRegistry)
    function loadConfigurationFromChain(
        address serviceManagerAddress
    ) internal view returns (WavsMirrorDeploymentLib.InitialConfiguration memory) {
        WavsServiceManager serviceManager = WavsServiceManager(serviceManagerAddress);
        ECDSAStakeRegistry stakeRegistry = ECDSAStakeRegistry(serviceManager.stakeRegistry());

        WavsMirrorDeploymentLib.InitialConfiguration memory cfg;

        // get config values
        cfg.thresholdWeight = stakeRegistry.getLastCheckpointThresholdWeight();
        cfg.quorumNumerator = serviceManager.quorumNumerator();
        cfg.quorumDenominator = serviceManager.quorumDenominator();

        // get operators
        IAllocationManager allocationManager =
            IAllocationManager(serviceManager.allocationManager());
        OperatorSet memory opSetQuery = OperatorSet({avs: serviceManagerAddress, id: 1});
        cfg.operators = allocationManager.getMembers(opSetQuery);

        // get operator info
        cfg.signingKeyAddresses = new address[](cfg.operators.length);
        cfg.weights = new uint256[](cfg.operators.length);
        for (uint256 i = 0; i < cfg.operators.length; i++) {
            cfg.signingKeyAddresses[i] = stakeRegistry.getLatestOperatorSigningKey(cfg.operators[i]);
            cfg.weights[i] = stakeRegistry.getOperatorWeight(cfg.operators[i]);
        }

        return cfg;
    }

    function readDeploymentJson(
        uint256 chainId
    ) internal returns (DeploymentData memory) {
        return readDeploymentJson("deployments/wavs-mirror/", chainId);
    }

    function readDeploymentJson(
        string memory directoryPath,
        uint256 chainId
    ) internal returns (DeploymentData memory) {
        string memory fileName = string.concat(directoryPath, VM.toString(chainId), ".json");

        if (!VM.exists(fileName)) {
            revert WavsMirrorDeploymentLib__DeploymentFileNotFound();
        }

        string memory json = VM.readFile(fileName);

        DeploymentData memory data;
        data.wavsServiceManager = json.readAddress(".contracts.wavsServiceManager");
        data.stakeRegistry = json.readAddress(".contracts.stakeRegistry");
        data.mirrorServiceHandler = json.readAddress(".contracts.mirrorServiceHandler");
        data.mirrorServiceManagerHandler =
            json.readAddress(".contracts.mirrorServiceManagerHandler");

        return data;
    }

    /// write to default output path
    function writeDeploymentJson(
        DeploymentData memory data
    ) internal {
        writeDeploymentJson("deployments/wavs-mirror/", block.chainid, data);
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
            "\",\"MirrorServiceHandler\":\"",
            data.mirrorServiceHandler.toHexString(),
            "\",\"MirrorServiceManagerHandler\":\"",
            data.mirrorServiceManagerHandler.toHexString(),
            "\"}"
        );
    }
}
