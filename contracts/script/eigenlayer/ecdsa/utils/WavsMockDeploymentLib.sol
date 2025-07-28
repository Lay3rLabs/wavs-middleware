// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {
    IECDSAStakeRegistryTypes,
    IStrategy
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {MirrorStakeRegistry} from "src/eigenlayer/ecdsa/MirrorStakeRegistry.sol";
import {WavsServiceManager} from "src/eigenlayer/ecdsa/WavsServiceManager.sol";
import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";

/**
 * @title WavsMockDeploymentLib
 * @author Lay3rLabs
 * @notice This library contains functions for deploying the WavsMock contracts.
 * @dev This library is used to deploy the WavsMock contracts.
 */
library WavsMockDeploymentLib {
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
     */
    struct DeploymentData {
        address wavsServiceManager;
        address stakeRegistry;
    }

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice The error for the config file not found.
    error WavsMockDeploymentLib__ConfigFileNotFound();
    /// @notice The error for the deployment file not found.
    error WavsMockDeploymentLib__DeploymentFileNotFound();
    /// @notice The error for the operators and signing keys length mismatch.
    error WavsMockDeploymentLib__OperatorsAndSigningKeysLengthMismatch();
    /// @notice The error for the operators and weights length mismatch.
    error WavsMockDeploymentLib__OperatorsAndWeightsLengthMismatch();
    /// @notice The error for the service handlers already deployed.
    error WavsMockDeploymentLib__ServiceHandlersAlreadyDeployed();

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
     * @param serviceManagerAddress The service manager address.
     * @param configuration The initial configuration.
     */
    function setInitialConfiguration(
        address serviceManagerAddress,
        InitialConfiguration memory configuration
    ) internal {
        WavsServiceManager serviceManager = WavsServiceManager(serviceManagerAddress);
        MirrorStakeRegistry stakeRegistry = MirrorStakeRegistry(serviceManager.getStakeRegistry());

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
     * @notice The load configuration function.
     * @param filePath The file path.
     * @return The initial configuration.
     */
    function loadConfiguration(
        string memory filePath
    ) internal returns (WavsMockDeploymentLib.InitialConfiguration memory) {
        // load the config
        if (!VM.exists(filePath)) {
            revert WavsMockDeploymentLib__ConfigFileNotFound();
        }
        string memory json = VM.readFile(filePath);

        // parse it
        WavsMockDeploymentLib.InitialConfiguration memory cfg;
        cfg.operators = abi.decode(VM.parseJson(json, ".operators"), (address[]));
        cfg.signingKeyAddresses =
            abi.decode(VM.parseJson(json, ".signingKeyAddresses"), (address[]));
        cfg.weights = abi.decode(VM.parseJson(json, ".weights"), (uint256[]));
        if (cfg.operators.length != cfg.signingKeyAddresses.length) {
            revert WavsMockDeploymentLib__OperatorsAndSigningKeysLengthMismatch();
        }
        if (cfg.operators.length != cfg.weights.length) {
            revert WavsMockDeploymentLib__OperatorsAndWeightsLengthMismatch();
        }

        cfg.thresholdWeight = abi.decode(VM.parseJson(json, ".threshold"), (uint256));
        cfg.quorumNumerator = abi.decode(VM.parseJson(json, ".quorumNumerator"), (uint256));
        cfg.quorumDenominator = abi.decode(VM.parseJson(json, ".quorumDenominator"), (uint256));
        return cfg;
    }

    /**
     * @notice The write deployment JSON function.
     * @param data The deployment data.
     * @param fileName The file name.
     */
    function writeDeploymentJson(DeploymentData memory data, string memory fileName) internal {
        address proxyAdmin = address(UpgradeableProxyLib.getProxyAdmin(data.wavsServiceManager));

        string memory deploymentData = _generateDeploymentJson(data, proxyAdmin);

        if (!VM.exists("deployments/wavs-ecdsa")) {
            VM.createDir("deployments/wavs-ecdsa", true);
        }

        VM.writeFile(string.concat("deployments/wavs-ecdsa/", fileName, ".json"), deploymentData);
        console2.log(
            string.concat(
                "Deployment artifacts written to: deployments/wavs-ecdsa/", fileName, ".json"
            )
        );
    }

    /**
     * @notice The generate deployment JSON function.
     * @param data The deployment data.
     * @param proxyAdmin The proxy admin address.
     * @return The deployment JSON.
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
     * @return The contracts JSON.
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
            "\"}"
        );
    }
}
