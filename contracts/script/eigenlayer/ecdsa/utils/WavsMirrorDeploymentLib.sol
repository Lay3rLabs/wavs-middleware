// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {console2} from "forge-std/Test.sol";
import {Vm, VmSafe} from "forge-std/Vm.sol";
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

import {IPOAStakeRegistry} from "@poa-middleware/src/ecdsa/interfaces/IPOAStakeRegistry.sol";
import {IWavsServiceManager} from "src/eigenlayer/ecdsa/interfaces/IWavsServiceManager.sol";
import {MirrorStakeRegistry} from "src/eigenlayer/ecdsa/MirrorStakeRegistry.sol";
import {MirrorOperatorSyncHandler} from
    "src/eigenlayer/ecdsa/handlers/MirrorOperatorSyncHandler.sol";
import {MirrorQuorumSyncHandler} from "src/eigenlayer/ecdsa/handlers/MirrorQuorumSyncHandler.sol";
import {WavsServiceManager} from "src/eigenlayer/ecdsa/WavsServiceManager.sol";
import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";

/**
 * @title WavsMirrorDeploymentLib
 * @author Lay3rLabs
 * @notice This library contains functions for deploying the WavsMirror contracts.
 * @dev This library is used to deploy the WavsMirror contracts.
 */
library WavsMirrorDeploymentLib {
    using stdJson for *;
    using Strings for *;
    using UpgradeableProxyLib for address;

    /**
     * @notice The initial configuration struct.
     * @param operators The operators.
     * @param signingKeyAddresses The signing key addresses.
     * @param weights The weights.
     * @param thresholdWeight The threshold weight.
     */
    struct InitialConfiguration {
        address[] operators;
        address[] signingKeyAddresses;
        uint256[] weights;
        uint256 thresholdWeight;
        uint256 quorumNumerator;
        uint256 quorumDenominator;
    }

    /**
     * @notice The deployment data struct.
     * @param wavsServiceManager The WAVS service manager address.
     * @param stakeRegistry The stake registry address.
     * @param operatorSyncHandler The operator sync handler address.
     * @param quorumSyncHandler The quorum sync handler address.
     */
    struct DeploymentData {
        address wavsServiceManager;
        address stakeRegistry;
        address operatorSyncHandler;
        address quorumSyncHandler;
    }

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice The error for the config file not found.
    error WavsMirrorDeploymentLib__ConfigFileNotFound();
    /// @notice The error for the deployment file not found.
    error WavsMirrorDeploymentLib__DeploymentFileNotFound();
    /// @notice The error for the operators and signing keys length mismatch.
    error WavsMirrorDeploymentLib__OperatorsAndSigningKeysLengthMismatch();
    /// @notice The error for the operators and weights length mismatch.
    error WavsMirrorDeploymentLib__OperatorsAndWeightsLengthMismatch();
    /// @notice The error for the service handlers already deployed.
    error WavsMirrorDeploymentLib__ServiceHandlersAlreadyDeployed();

    /**
     * @notice The deploy contracts function.
     * @param proxyAdmin The proxy admin address.
     * @return result The deployment data.
     */
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

    /**
     * @notice The set initial configuration function.
     * @param deployment The deployment data.
     * @param configuration The initial configuration.
     */
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

    /**
     * @notice The deploy service handlers function.
     * @param deployment The deployment data.
     * @return result The deployment data.
     */
    function deployServiceHandlers(
        DeploymentData memory deployment
    ) internal returns (DeploymentData memory) {
        if (
            deployment.operatorSyncHandler != address(0)
                || deployment.quorumSyncHandler != address(0)
        ) {
            revert WavsMirrorDeploymentLib__ServiceHandlersAlreadyDeployed();
        }

        DeploymentData memory result = deployment;

        // deploy the operator sync handler
        MirrorStakeRegistry stakeRegistry = MirrorStakeRegistry(result.stakeRegistry);
        result.operatorSyncHandler = address(new MirrorOperatorSyncHandler(stakeRegistry));
        stakeRegistry.transferOwnership(result.operatorSyncHandler);

        // deploy the quorum sync handler
        WavsServiceManager serviceManager = WavsServiceManager(result.wavsServiceManager);
        result.quorumSyncHandler = address(new MirrorQuorumSyncHandler(serviceManager));
        serviceManager.transferOwnership(result.quorumSyncHandler);

        return result;
    }

    /**
     * @notice The load configuration function.
     * @param filePath The file path.
     * @return cfg The initial configuration.
     */
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

    /**
     * @notice The write configuration function.
     * @param filePath The file path.
     * @param config The configuration.
     */
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

    /**
     * @notice The load configuration from chain function.
     * @param serviceManagerAddress The service manager address.
     * @param isPOA Whether this is a POA deployment.
     * @return cfg The initial configuration.
     */
    function loadConfigurationFromChain(
        address serviceManagerAddress,
        bool isPOA
    ) internal returns (WavsMirrorDeploymentLib.InitialConfiguration memory) {
        WavsMirrorDeploymentLib.InitialConfiguration memory cfg;

        if (isPOA) {
            // For POA, serviceManagerAddress IS the POAStakeRegistry
            // (it implements both IPOAStakeRegistry and IWavsServiceManager)
            IPOAStakeRegistry poaRegistry = IPOAStakeRegistry(serviceManagerAddress);

            cfg.thresholdWeight = poaRegistry.getLastCheckpointThresholdWeight();
            (cfg.quorumNumerator, cfg.quorumDenominator) = poaRegistry.getLastCheckpointQuorum();

            // Get operators from POA events
            cfg.operators = loadOperatorsFromPOAEvents(serviceManagerAddress);

            // Get operator signing keys and weights
            cfg.signingKeyAddresses = new address[](cfg.operators.length);
            cfg.weights = new uint256[](cfg.operators.length);
            for (uint256 i = 0; i < cfg.operators.length; ++i) {
                cfg.signingKeyAddresses[i] = poaRegistry.getLatestOperatorSigningKey(cfg.operators[i]);
                cfg.weights[i] = IWavsServiceManager(serviceManagerAddress).getOperatorWeight(cfg.operators[i]);
            }
        } else {
            // EigenLayer mode
            WavsServiceManager serviceManager = WavsServiceManager(serviceManagerAddress);
            ECDSAStakeRegistry stakeRegistry = ECDSAStakeRegistry(serviceManager.stakeRegistry());

            cfg.thresholdWeight = stakeRegistry.getLastCheckpointThresholdWeight();
            cfg.quorumNumerator = serviceManager.quorumNumerator();
            cfg.quorumDenominator = serviceManager.quorumDenominator();

            address allocationManagerAddr = serviceManager.getAllocationManager();
            IAllocationManager allocationManager = IAllocationManager(allocationManagerAddr);
            OperatorSet memory opSetQuery = OperatorSet({avs: serviceManagerAddress, id: 0});
            cfg.operators = allocationManager.getMembers(opSetQuery);

            cfg.signingKeyAddresses = new address[](cfg.operators.length);
            cfg.weights = new uint256[](cfg.operators.length);
            for (uint256 i = 0; i < cfg.operators.length; ++i) {
                cfg.signingKeyAddresses[i] = stakeRegistry.getLatestOperatorSigningKey(cfg.operators[i]);
                cfg.weights[i] = stakeRegistry.getOperatorWeight(cfg.operators[i]);
            }
        }

        return cfg;
    }

    /**
     * @notice Loads operators from POA stake registry by querying OperatorRegistered events
     * @param stakeRegistryAddress The stake registry address
     * @return operators Array of unique operator addresses
     */
    function loadOperatorsFromPOAEvents(
        address stakeRegistryAddress
    ) internal returns (address[] memory operators) {
        bytes32[] memory topics = new bytes32[](1);
        topics[0] = keccak256("OperatorRegistered(address)");

        uint256 fromBlock = block.number > 5000 ? block.number - 5000 : 0;
        VmSafe.EthGetLogs[] memory logs =
            VM.eth_getLogs(fromBlock, block.number, stakeRegistryAddress, topics);

        address[] memory tempOperators = new address[](logs.length);
        uint256 count = 0;

        for (uint256 i = 0; i < logs.length; i++) {
            address operator = address(uint160(uint256(logs[i].topics[1])));

            bool found = false;
            for (uint256 j = 0; j < count; j++) {
                if (tempOperators[j] == operator) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                tempOperators[count] = operator;
                count++;
            }
        }

        // Create properly sized array
        operators = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            operators[i] = tempOperators[i];
        }

        return operators;
    }

    /**
     * @notice The read deployment JSON function.
     * @param chainId The chain ID.
     * @return data The deployment data.
     */
    function readDeploymentJson(
        uint256 chainId
    ) internal returns (DeploymentData memory) {
        return readDeploymentJson("deployments/wavs-mirror/", chainId);
    }

    /**
     * @notice The read deployment JSON function.
     * @param directoryPath The directory path.
     * @param chainId The chain ID.
     * @return data The deployment data.
     */
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
        data.operatorSyncHandler = json.readAddress(".contracts.operatorSyncHandler");
        data.quorumSyncHandler = json.readAddress(".contracts.quorumSyncHandler");

        return data;
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

        if (!VM.exists("deployments/wavs-ecdsa")) {
            VM.createDir("deployments/wavs-ecdsa", true);
        }

        VM.writeFile("deployments/wavs-ecdsa/mirror_deploy.json", deploymentData);
        console2.log("Deployment artifacts written to: deployments/wavs-ecdsa/mirror_deploy.json");
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
            "\",\"operatorSyncHandler\":\"",
            data.operatorSyncHandler.toHexString(),
            "\",\"quorumSyncHandler\":\"",
            data.quorumSyncHandler.toHexString(),
            "\"}"
        );
    }
}
