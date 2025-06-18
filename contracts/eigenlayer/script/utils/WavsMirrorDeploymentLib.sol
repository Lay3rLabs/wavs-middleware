// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/Test.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {MirrorStakeRegistry} from "../../src/MirrorStakeRegistry.sol";
import {MirrorServiceHandler} from "../../src/handlers/MirrorServiceHandler.sol";
import {MirrorServiceManagerHandler} from "../../src/handlers/MirrorServiceManagerHandler.sol";
import {WavsServiceManager} from "../../src/WavsServiceManager.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {IAllocationManagerTypes, IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {OperatorSet} from "@eigenlayer/contracts/libraries/OperatorSetLib.sol";
import {IECDSAStakeRegistryTypes, IStrategy} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library WavsMirrorDeploymentLib {
    using stdJson for *;
    using Strings for *;
    using UpgradeableProxyLib for address;

    struct InitialConfiguration {
        // original operators
        address[] operators;
        address[] signingKeys;
        uint256[] weights;
        // stake registry threshold
        uint256 thresholdWeight;
        // service manager threshold
        uint256 quorumNumerator;
        uint256 quorumDenominator;
    }

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct DeploymentData {
        address WavsServiceManager;
        address stakeRegistry;
        address MirrorServiceHandler;
        address MirrorServiceManagerHandler;
    }

    function deployContracts(address proxyAdmin) internal returns (DeploymentData memory) {
        DeploymentData memory result;

        // FIXME: remove debug
        // (, address msgSender, address txOrigin) = vm.readCallers();
        // console2.log("deployContracts");
        // console2.log("msgSender", msgSender);
        // console2.log("txOrigin", txOrigin);
        // console2.log("msg.sender", msg.sender);

        // use an mock quorum so checks pass, we don't use it internally
        IStrategy mockStrategyInstance = IStrategy(address(1)); // Using address(1) instead of address(0)
        IECDSAStakeRegistryTypes.StrategyParams memory strategyParams = IECDSAStakeRegistryTypes.StrategyParams({
            strategy: mockStrategyInstance,
            multiplier: 10000 // 100% in basis points
        });
        IECDSAStakeRegistryTypes.StrategyParams[] memory strategies = new IECDSAStakeRegistryTypes.StrategyParams[](1);
        strategies[0] = strategyParams;
        IECDSAStakeRegistryTypes.Quorum memory quorum = IECDSAStakeRegistryTypes.Quorum({strategies: strategies});

        // First, deploy upgradeable proxy contracts that will point to the implementations.
        result.WavsServiceManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.stakeRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        // Deploy the implementation contracts, using the proxy contracts as inputs
        address stakeRegistryImpl = address(new MirrorStakeRegistry());
        // Use 0 address for contracts we don't use
        address WavsServiceManagerImpl =
            address(new WavsServiceManager(address(0), result.stakeRegistry, address(0), address(0), address(0)));
        // Upgrade contracts
        bytes memory stakeRegistryUpgradeCall = abi.encodeCall(
            MirrorStakeRegistry.initialize,
            (result.WavsServiceManager, 100, quorum) // TODO: dynamically update threshold (?)
        );
        bytes memory WavsServiceManagerUpgradeCall =
            abi.encodeCall(WavsServiceManager.initialize, (msg.sender, msg.sender));
        UpgradeableProxyLib.upgradeAndCall(result.stakeRegistry, stakeRegistryImpl, stakeRegistryUpgradeCall);
        UpgradeableProxyLib.upgradeAndCall(
            result.WavsServiceManager, WavsServiceManagerImpl, WavsServiceManagerUpgradeCall
        );

        // TODO: This is incredibly stupid,
        // when we implement out own stake registry, pass owner as an argument
        bytes memory stakeRegistryOwnerUpgradeCall = abi.encodeCall(Ownable.transferOwnership, (msg.sender));
        UpgradeableProxyLib.upgradeAndCall(result.stakeRegistry, stakeRegistryImpl, stakeRegistryOwnerUpgradeCall);

        return result;
    }

    function setInitialConfiguration(DeploymentData memory deployment, InitialConfiguration memory configuration)
        internal
    {
        MirrorStakeRegistry stakeRegistry = MirrorStakeRegistry(deployment.stakeRegistry);
        WavsServiceManager serviceManager = WavsServiceManager(deployment.WavsServiceManager);

        // // FIXME: remove debug
        // console2.log("owners");
        // console2.log(stakeRegistry.owner());
        // console2.log(serviceManager.owner());

        // TODO: fails here on broadcast, no error message. removing as unused in README.md
        // stakeRegistry.updateStakeThreshold(configuration.thresholdWeight);
        stakeRegistry.batchSetOperatorDetails(configuration.operators, configuration.signingKeys, configuration.weights);
        serviceManager.setQuorumThreshold(configuration.quorumNumerator, configuration.quorumDenominator);
    }

    // deploy service handlers to run mirroring and transfer ownership
    // must be called by the owner of the service manager
    function deployServiceHandlers(DeploymentData memory deployment) internal returns (DeploymentData memory) {
        if (deployment.MirrorServiceHandler != address(0) || deployment.MirrorServiceManagerHandler != address(0)) {
            revert("Service handlers already deployed");
        }

        DeploymentData memory result = deployment;

        // deploy the stake registry handler
        MirrorStakeRegistry stakeRegistry = MirrorStakeRegistry(result.stakeRegistry);
        result.MirrorServiceHandler = address(new MirrorServiceHandler(stakeRegistry));
        stakeRegistry.transferOwnership(result.MirrorServiceHandler);

        // deploy the service manager handler
        WavsServiceManager serviceManager = WavsServiceManager(result.WavsServiceManager);
        result.MirrorServiceManagerHandler = address(new MirrorServiceManagerHandler(serviceManager));
        serviceManager.transferOwnership(result.MirrorServiceManagerHandler);

        return result;
    }

    function loadConfiguration(string memory filePath)
        internal
        returns (WavsMirrorDeploymentLib.InitialConfiguration memory)
    {
        // load the config
        require(vm.exists(filePath), string(abi.encodePacked("Config file does not exist: ", filePath)));
        string memory json = vm.readFile(filePath);

        // parse it
        WavsMirrorDeploymentLib.InitialConfiguration memory cfg;
        cfg.operators = abi.decode(vm.parseJson(json, ".operators"), (address[]));
        cfg.signingKeys = abi.decode(vm.parseJson(json, ".signingKeys"), (address[]));
        cfg.weights = abi.decode(vm.parseJson(json, ".weights"), (uint256[]));
        require(cfg.operators.length == cfg.signingKeys.length, "Operators and signingKeys must have the same length");
        require(cfg.operators.length == cfg.weights.length, "Operators and weights must have the same length");

        cfg.thresholdWeight = abi.decode(vm.parseJson(json, ".threshold"), (uint256));
        cfg.quorumNumerator = abi.decode(vm.parseJson(json, ".quorumNumerator"), (uint256));
        cfg.quorumDenominator = abi.decode(vm.parseJson(json, ".quorumDenominator"), (uint256));
        return cfg;
    }

    function writeConfiguration(string memory filePath, WavsMirrorDeploymentLib.InitialConfiguration memory config)
        internal
    {
        string memory objectKey = "WavsMirrorConfigJson"; // An arbitrary unique key for forge's internal JSON object tracking

        // Serialize each field of the configuration into the JSON buffer
        vm.serializeAddress(objectKey, "operators", config.operators);
        vm.serializeAddress(objectKey, "signingKeys", config.signingKeys);
        vm.serializeUint(objectKey, "weights", config.weights);
        vm.serializeUint(objectKey, "threshold", config.thresholdWeight);
        vm.serializeUint(objectKey, "quorumNumerator", config.quorumNumerator);
        string memory jsonOutput = vm.serializeUint(objectKey, "quorumDenominator", config.quorumDenominator);

        // Write the composed JSON string to the specified file
        vm.writeFile(filePath, jsonOutput);
    }

    // This should be run on the source chain (with ECDSAStakeRegistry)
    // All other functions should run on mirror chain (with MirrorStakeRegistry)
    function loadConfigurationFromChain(address serviceManagerAddress)
        internal
        view
        returns (WavsMirrorDeploymentLib.InitialConfiguration memory)
    {
        WavsServiceManager serviceManager = WavsServiceManager(serviceManagerAddress);
        ECDSAStakeRegistry stakeRegistry = ECDSAStakeRegistry(serviceManager.stakeRegistry());

        WavsMirrorDeploymentLib.InitialConfiguration memory cfg;

        // get config values
        cfg.thresholdWeight = stakeRegistry.getLastCheckpointThresholdWeight();
        cfg.quorumNumerator = serviceManager.quorumNumerator();
        cfg.quorumDenominator = serviceManager.quorumDenominator();

        // get operators
        IAllocationManager allocationManager = IAllocationManager(serviceManager.allocationManager());
        OperatorSet memory opSetQuery = OperatorSet({avs: serviceManagerAddress, id: 1});
        cfg.operators = allocationManager.getMembers(opSetQuery);

        // get operator info
        cfg.signingKeys = new address[](cfg.operators.length);
        cfg.weights = new uint256[](cfg.operators.length);
        for (uint256 i = 0; i < cfg.operators.length; i++) {
            cfg.signingKeys[i] = stakeRegistry.getLatestOperatorSigningKey(cfg.operators[i]);
            cfg.weights[i] = stakeRegistry.getOperatorWeight(cfg.operators[i]);
        }

        return cfg;
    }

    function readDeploymentJson(uint256 chainId) internal returns (DeploymentData memory) {
        return readDeploymentJson("deployments/wavs-mirror/", chainId);
    }

    function readDeploymentJson(string memory directoryPath, uint256 chainId)
        internal
        returns (DeploymentData memory)
    {
        string memory fileName = string.concat(directoryPath, vm.toString(chainId), ".json");

        require(vm.exists(fileName), "Deployment file does not exist");

        string memory json = vm.readFile(fileName);

        DeploymentData memory data;
        data.WavsServiceManager = json.readAddress(".contracts.WavsServiceManager");
        data.stakeRegistry = json.readAddress(".contracts.stakeRegistry");
        data.MirrorServiceHandler = json.readAddress(".contracts.MirrorServiceHandler");
        data.MirrorServiceManagerHandler = json.readAddress(".contracts.MirrorServiceManagerHandler");

        return data;
    }

    /// write to default output path
    function writeDeploymentJson(DeploymentData memory data) internal {
        writeDeploymentJson("deployments/wavs-mirror/", block.chainid, data);
    }

    function writeDeploymentJson(string memory outputPath, uint256 chainId, DeploymentData memory data) internal {
        address proxyAdmin = address(UpgradeableProxyLib.getProxyAdmin(data.WavsServiceManager));

        string memory deploymentData = _generateDeploymentJson(data, proxyAdmin);

        string memory fileName = string.concat(outputPath, vm.toString(chainId), ".json");
        if (!vm.exists(outputPath)) {
            vm.createDir(outputPath, true);
        }

        vm.writeFile(fileName, deploymentData);
        console2.log("Deployment artifacts written to:", fileName);
    }

    function _generateDeploymentJson(DeploymentData memory data, address proxyAdmin)
        private
        view
        returns (string memory)
    {
        return string.concat(
            "{",
            '"lastUpdate":{',
            '"timestamp":"',
            vm.toString(block.timestamp),
            '",',
            '"block_number":"',
            vm.toString(block.number),
            '"',
            "},",
            '"addresses":',
            _generateContractsJson(data, proxyAdmin),
            "}"
        );
    }

    function _generateContractsJson(DeploymentData memory data, address proxyAdmin)
        private
        view
        returns (string memory)
    {
        return string.concat(
            '{"proxyAdmin":"',
            proxyAdmin.toHexString(),
            '","WavsServiceManager":"',
            data.WavsServiceManager.toHexString(),
            '","WavsServiceManagerImpl":"',
            data.WavsServiceManager.getImplementation().toHexString(),
            '","stakeRegistry":"',
            data.stakeRegistry.toHexString(),
            '","stakeRegistryImpl":"',
            data.stakeRegistry.getImplementation().toHexString(),
            '","MirrorServiceHandler":"',
            data.MirrorServiceHandler.toHexString(),
            '","MirrorServiceManagerHandler":"',
            data.MirrorServiceManagerHandler.toHexString(),
            '"}'
        );
    }
}
