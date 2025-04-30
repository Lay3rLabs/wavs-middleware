// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
import {WavsMiddlewareDeploymentLib} from "./utils/WavsMiddlewareDeplomentLib.sol";
import {ReadCoreLib} from "./utils/ReadCoreLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";
import {StrategyBase} from "@eigenlayer/contracts/strategies/StrategyBase.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {StrategyFactory} from "@eigenlayer/contracts/strategies/StrategyFactory.sol";
import {StrategyManager} from "@eigenlayer/contracts/core/StrategyManager.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IECDSAStakeRegistryTypes, IStrategy} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {WavsServiceManager} from "../src/WavsServiceManager.sol";
import {WavsAVSRegistrar} from "../src/WavsAVSRegistrar.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAllocationManager, IAllocationManagerTypes} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {IAVSRegistrar} from "@eigenlayer/contracts/interfaces/IAVSRegistrar.sol";

/**
 * @title WavsDeployment
 * @notice A Forge script to deploy and configure WAVS middleware contracts
 * @dev This script replaces the docker/deploy.sh bash script
 */
contract WavsDeployment is Script, IECDSAStakeRegistryTypes {
    using ReadCoreLib for *;
    using UpgradeableProxyLib for address;
    using Strings for *;

    // Environment variables
    string public constant ENV_PRIVATE_KEY = "FUNDED_KEY";
    string public constant ENV_LST_STRATEGY = "LST_STRATEGY_ADDRESS";
    string public constant ENV_LST_CONTRACT = "LST_CONTRACT_ADDRESS";
    string public constant ENV_DEPLOY_ENV = "DEPLOY_ENV";
    string public constant ENV_TESTNET_RPC = "TESTNET_RPC_URL";
    string public constant ENV_METADATA_URI = "METADATA_URI";

    // Deployment configuration
    uint256 private deployerPrivateKey;
    address private deployer;
    address private lstStrategyAddress;
    address private lstContractAddress;
    string private deployEnv;
    string private metadataUri;

    // Deployment data
    WavsMiddlewareDeploymentLib.DeploymentData wavsMiddlewareDeployment;
    ReadCoreLib.DeploymentData coreDeployment;

    // Contract references
    address private stakeRegistryAddress;
    address private wavsServiceManagerAddress;
    address private avsRegistrarAddress;
    address private owner;

    /**
     * @notice Setup function to initialize environment variables
     */
    function setUp() public {
        string memory rawKey = vm.envString(ENV_PRIVATE_KEY);
        // Check if the private key has the 0x prefix, add it if missing
        if (
            bytes(rawKey).length > 0 &&
            bytes(rawKey)[0] != bytes("0")[0] &&
            bytes(rawKey)[1] != bytes("x")[0]
        ) {
            rawKey = string(abi.encodePacked("0x", rawKey));
        }

        deployerPrivateKey = vm.parseUint(rawKey);
        deployer = vm.rememberKey(deployerPrivateKey);
        vm.label(deployer, "Deployer");

        // Get environment configuration
        lstStrategyAddress = vm.envAddress(ENV_LST_STRATEGY);
        lstContractAddress = vm.envAddress(ENV_LST_CONTRACT);
        deployEnv = vm.envString(ENV_DEPLOY_ENV);
        metadataUri = vm.envString(ENV_METADATA_URI);

        // Read core deployments
        coreDeployment = ReadCoreLib.readDeploymentJson(
            "deployments/core/",
            block.chainid
        );
    }

    /**
     * @notice Main deployment function
     */
    function run() external {
        console2.log(
            "Starting WAVS middleware deployment on chain",
            block.chainid
        );
        console2.log("Deployer address:", deployer);
        console2.log("Environment:", deployEnv);

        // 1. Deploy middleware contracts
        _deployMiddlewareContracts();

        // 2. Configure stake registry and service manager
        _configureContracts();

        console2.log("WAVS middleware deployment completed successfully");
    }

    /**
     * @notice Deploy middleware contracts
     */
    function _deployMiddlewareContracts() private {
        vm.startBroadcast(deployerPrivateKey);

        // Create quorum configuration
        Quorum memory quorum;

        // Create fixed-size array for strategies
        StrategyParams[] memory strategyParams = new StrategyParams[](1);
        strategyParams[0] = StrategyParams({
            strategy: IStrategy(lstStrategyAddress),
            multiplier: 10_000
        });
        quorum.strategies = strategyParams;

        // Deploy proxy admin and contracts
        address proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();
        wavsMiddlewareDeployment = WavsMiddlewareDeploymentLib.deployContracts(
            proxyAdmin,
            coreDeployment,
            quorum
        );

        // Save LST strategy
        wavsMiddlewareDeployment.strategy = lstStrategyAddress;

        vm.stopBroadcast();

        // Save addresses for later use
        stakeRegistryAddress = wavsMiddlewareDeployment.stakeRegistry;
        wavsServiceManagerAddress = wavsMiddlewareDeployment.WavsServiceManager;
        avsRegistrarAddress = wavsMiddlewareDeployment.avsRegistrar;

        // Verify deployment
        _verifyDeployment();

        // Write deployment JSON
        WavsMiddlewareDeploymentLib.writeDeploymentJson(
            wavsMiddlewareDeployment
        );

        // Print deployment addresses
        console2.log("Middleware contracts deployed with addresses:");
        console2.log("- WavsServiceManager:", wavsServiceManagerAddress);
        console2.log("- StakeRegistry:", stakeRegistryAddress);
        console2.log("- AVSRegistrar:", avsRegistrarAddress);
        console2.log("- Strategy:", wavsMiddlewareDeployment.strategy);
    }

    /**
     * @notice Configure stake registry and service manager
     */
    function _configureContracts() private {
        vm.startBroadcast(deployerPrivateKey);

        // Get owner of stake registry
        owner = ECDSAStakeRegistry(stakeRegistryAddress).owner();

        if (keccak256(bytes(deployEnv)) == keccak256(bytes("LOCAL"))) {
            // Impersonate owner on local environment
            vm.startPrank(owner);
        }

        // 1. Update quorum configuration for multiple strategies
        _updateQuorumConfig();

        // 2. Update minimum weight for operators
        _updateMinimumWeight();

        // 3. Set AVS registrar
        _setAVSRegistrar();

        // 4. Update metadata URI
        _updateMetadataURI();

        // 5. Create operator sets
        _createOperatorSets();

        if (keccak256(bytes(deployEnv)) == keccak256(bytes("LOCAL"))) {
            vm.stopPrank();
        }

        vm.stopBroadcast();
    }

    /**
     * @notice Update quorum configuration with multiple strategies
     */
    function _updateQuorumConfig() private {
        console2.log("Updating quorum configuration");

        // Define strategies with weights
        address[] memory strategies = new address[](12);
        uint96[] memory weights = new uint96[](12);

        // Standard strategy addresses from script (with correct checksums)
        strategies[0] = 0x05037A81BD7B4C9E0F7B430f1F2A22c31a2FD943;
        strategies[1] = 0x31B6F59e1627cEfC9fA174aD03859fC337666af7;
        strategies[2] = 0x3A8fBdf9e77DFc25d09741f51d3E181b25d0c4E0;
        strategies[3] = 0x46281E3B7fDcACdBa44CADf069a94a588Fd4C6Ef;
        strategies[4] = 0x70EB4D3c164a6B4A5f908D4FBb5a9cAfFb66bAB6;
        strategies[5] = 0x7673a47463F80c6a3553Db9E54c8cDcd5313d0ac;
        strategies[6] = 0x78dBcbEF8fF94eC7F631c23d38d197744a323868;
        strategies[7] = 0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3;
        strategies[8] = 0x80528D6e9A2BAbFc766965E0E26d5aB08D9CFaF9;
        strategies[9] = 0x9281ff96637710Cd9A5CAcce9c6FAD8C9F54631c;
        strategies[10] = 0xaccc5A86732BE85b5012e8614AF237801636F8e5;
        strategies[11] = 0xAD76D205564f955A9c18103C4422D1Cd94016899;

        // Distribute weights: first one gets 837, rest get 833
        weights[0] = 837;
        for (uint i = 1; i < strategies.length; i++) {
            weights[i] = 833;
        }

        // Create strategy params array
        StrategyParams[] memory strategyParams = new StrategyParams[](
            strategies.length
        );
        for (uint i = 0; i < strategies.length; i++) {
            strategyParams[i] = StrategyParams({
                strategy: IStrategy(strategies[i]),
                multiplier: weights[i]
            });
        }

        // Create quorum and update
        Quorum memory updatedQuorum;
        updatedQuorum.strategies = strategyParams;

        // Update quorum config
        ECDSAStakeRegistry(stakeRegistryAddress).updateQuorumConfig(
            updatedQuorum,
            new address[](0)
        );
    }

    /**
     * @notice Update minimum weight for operators
     */
    function _updateMinimumWeight() private {
        console2.log("Updating minimum weight");

        // Set a very low minimum weight (1) to ensure operators have enough stake
        ECDSAStakeRegistry(stakeRegistryAddress).updateMinimumWeight(
            1,
            new address[](0)
        );
    }

    /**
     * @notice Set AVS registrar
     */
    function _setAVSRegistrar() private {
        console2.log("Setting AVS registrar");

        // Set AVS registrar in WavsServiceManager - cast to IAVSRegistrar
        WavsServiceManager(wavsServiceManagerAddress).setAVSRegistrar(
            IAVSRegistrar(avsRegistrarAddress)
        );
    }

    /**
     * @notice Update metadata URI
     */
    function _updateMetadataURI() private {
        console2.log("Updating metadata URI");

        // Update AVS metadata URI
        WavsServiceManager(wavsServiceManagerAddress).updateAVSMetadataURI(
            metadataUri
        );
    }

    /**
     * @notice Create operator sets
     */
    function _createOperatorSets() private {
        console2.log("Creating operator sets");

        // Create a single operator set (can be configured to create more)
        uint32 setId = 1;
        address[] memory strategies = new address[](1);
        strategies[0] = lstStrategyAddress;

        // Create the CreateSetParams directly instead of using the type name
        IAllocationManager.CreateSetParams[]
            memory sets = new IAllocationManager.CreateSetParams[](1);

        // Use inline struct construction
        sets[0].operatorSetId = setId;
        sets[0].strategies = toIStrategyArray(strategies);

        // Create operator sets
        WavsServiceManager(wavsServiceManagerAddress).createOperatorSets(sets);
    }

    /**
     * @notice Helper function to convert address[] to IStrategy[]
     */
    function toIStrategyArray(
        address[] memory addresses
    ) private pure returns (IStrategy[] memory) {
        IStrategy[] memory strategies = new IStrategy[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            strategies[i] = IStrategy(addresses[i]);
        }
        return strategies;
    }

    /**
     * @notice Verify deployment
     */
    function _verifyDeployment() private view {
        require(
            wavsMiddlewareDeployment.stakeRegistry != address(0),
            "StakeRegistry address cannot be zero"
        );
        require(
            wavsMiddlewareDeployment.WavsServiceManager != address(0),
            "WavsServiceManager address cannot be zero"
        );
        require(
            wavsMiddlewareDeployment.strategy != address(0),
            "Strategy address cannot be zero"
        );
        require(
            wavsMiddlewareDeployment.avsRegistrar != address(0),
            "AVSRegistrar address cannot be zero"
        );
        require(
            coreDeployment.delegationManager != address(0),
            "DelegationManager address cannot be zero"
        );
        require(
            coreDeployment.avsDirectory != address(0),
            "AVSDirectory address cannot be zero"
        );
    }
}
