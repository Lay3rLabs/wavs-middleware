// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {WavsServiceManager} from "../src/WavsServiceManager.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IStrategy} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {IStrategyManager} from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import {ISignatureUtilsMixinTypes} from "@eigenlayer/contracts/interfaces/ISignatureUtilsMixin.sol";
import {IAllocationManager, IAllocationManagerTypes} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface for test ERC20 token that supports minting
interface TestERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

/**
 * @title RegisterOperator
 * @notice A Forge script to register an operator with the WAVS AVS
 * @dev This script replaces the docker/register.sh bash script
 */
contract RegisterOperator is Script {
    using Strings for *;

    // Contract addresses
    address private serviceManagerAddress;
    address private stakeRegistryAddress;
    address private lstStrategyAddress;
    address private lstContractAddress;
    address private strategyManagerAddress;
    address private delegationManagerAddress;
    address private avsDirectoryAddress;
    address private allocationManagerAddress;

    // Operator key
    uint256 private operatorPrivateKey;
    address private operatorAddress;

    // Deployer key for funding
    uint256 private deployerPrivateKey;
    address private deployerAddress;

    // Environment
    string private deployEnv;

    // Stake amount
    uint256 private stakeAmount;

    // Get command line arguments from json file
    function getCliArgs() internal returns (string[] memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script.json");
        // Check if file exists
        try vm.readFile(path) returns (string memory) {
            // If it exists, parse it
            return vm.parseJsonStringArray(vm.readFile(path), "$.args");
        } catch {
            // If file doesn't exist or can't be read, return empty array
            return new string[](0);
        }
    }

    function setUp() public {
        // Get operator key from environment variable
        string memory operatorKeyEnv = vm.envOr("OPERATOR_KEY", string(""));
        if (bytes(operatorKeyEnv).length > 0) {
            operatorPrivateKey = vm.parseUint(operatorKeyEnv);
        } else {
            // If no OPERATOR_KEY is provided, generate a new random key for testing
            operatorPrivateKey = uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        blockhash(block.number - 1)
                    )
                )
            );
            console2.log(
                "Generated new operator private key (hex):",
                vm.toString(operatorPrivateKey)
            );
        }

        operatorAddress = vm.addr(operatorPrivateKey);
        console2.log("Operator address:", operatorAddress);

        // Get stake amount (in ETH units) from environment variable or command line args
        string memory stakeAmountEnv = vm.envOr("STAKE_AMOUNT", string("0.1"));

        // For "0.1" specifically, use a hardcoded value
        if (keccak256(bytes(stakeAmountEnv)) == keccak256(bytes("0.1"))) {
            stakeAmount = 0.1 ether;
            console2.log("Using stake amount: 0.1 ETH");
            console2.log("Amount in wei:", stakeAmount);
        } else {
            // For other values, try to parse as integer amount
            try vm.parseUint(stakeAmountEnv) returns (uint256 parsed) {
                stakeAmount = parsed * 10 ** 18; // Convert to wei
                console2.log("Using stake amount:", stakeAmountEnv, "ETH");
                console2.log("Amount in wei:", stakeAmount);
            } catch {
                // Default fallback
                stakeAmount = 0.1 ether;
                console2.log(
                    "Failed to parse stake amount, using default: 0.1 ETH"
                );
                console2.log("Amount in wei:", stakeAmount);
            }
        }

        // Get deployer key for funding
        deployerPrivateKey = vm.envOr("FUNDED_KEY", uint256(0));
        if (deployerPrivateKey == 0) {
            revert("FUNDED_KEY environment variable is required");
        }
        deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("Deployer address:", deployerAddress);

        // Get deployment environment
        deployEnv = vm.envOr("DEPLOY_ENV", string("LOCAL"));

        // Read contract addresses from deployment file
        string memory deploymentPath = string.concat(
            vm.projectRoot(),
            "/deployments/wavs-middleware/",
            vm.toString(block.chainid),
            ".json"
        );

        // If the deployment file doesn't exist, try the .nodes/avs_deploy.json path
        if (!vm.exists(deploymentPath)) {
            // Try Docker path
            deploymentPath = "/root/.nodes/avs_deploy.json";

            if (!vm.exists(deploymentPath)) {
                // Try local path
                deploymentPath = string.concat(
                    vm.projectRoot(),
                    "/../.nodes/avs_deploy.json"
                );

                // Fail if no paths exist
                if (!vm.exists(deploymentPath)) {
                    revert("Deployment file not found");
                }
            }
        }

        // Parse the JSON to get the necessary addresses
        string memory json = vm.readFile(deploymentPath);
        serviceManagerAddress = vm.parseJsonAddress(
            json,
            ".addresses.WavsServiceManager"
        );
        stakeRegistryAddress = vm.parseJsonAddress(
            json,
            ".addresses.stakeRegistry"
        );

        // Get LST addresses from environment
        lstStrategyAddress = vm.envAddress("LST_STRATEGY_ADDRESS");
        lstContractAddress = vm.envAddress("LST_CONTRACT_ADDRESS");

        // Read core deployment addresses
        string memory coreDeploymentPath = string.concat(
            vm.projectRoot(),
            "/deployments/core/",
            vm.toString(block.chainid),
            ".json"
        );

        // If core deployment file doesn't exist, check if they're available in the service manager
        if (!vm.exists(coreDeploymentPath)) {
            // Get addresses from contracts
            avsDirectoryAddress = WavsServiceManager(serviceManagerAddress)
                .avsDirectory();
            allocationManagerAddress = WavsServiceManager(serviceManagerAddress)
                .allocationManager();

            // Since WavsServiceManager doesn't expose delegationManager, we'll
            // need to get it a different way - through environment or fallback
            delegationManagerAddress = vm.envOr(
                "DELEGATION_MANAGER_ADDRESS",
                address(0)
            );

            if (delegationManagerAddress == address(0)) {
                revert("Unable to get delegation manager address");
            }

            // Get strategy manager from environment variables
            strategyManagerAddress = vm.envOr(
                "STRATEGY_MANAGER_ADDRESS",
                address(0)
            );

            if (strategyManagerAddress == address(0)) {
                revert("Unable to get strategy manager address");
            }
        } else {
            // Read from the core deployment file
            string memory coreJson = vm.readFile(coreDeploymentPath);
            strategyManagerAddress = vm.parseJsonAddress(
                coreJson,
                ".addresses.strategyManager"
            );
            delegationManagerAddress = vm.parseJsonAddress(
                coreJson,
                ".addresses.delegation"
            );
            avsDirectoryAddress = vm.parseJsonAddress(
                coreJson,
                ".addresses.avsDirectory"
            );
            allocationManagerAddress = vm.parseJsonAddress(
                coreJson,
                ".addresses.allocationManager"
            );
        }

        // Validate addresses
        if (
            serviceManagerAddress == address(0) ||
            stakeRegistryAddress == address(0) ||
            lstStrategyAddress == address(0) ||
            lstContractAddress == address(0) ||
            strategyManagerAddress == address(0) ||
            delegationManagerAddress == address(0) ||
            avsDirectoryAddress == address(0) ||
            allocationManagerAddress == address(0)
        ) {
            revert("One or more required addresses are invalid");
        }
    }

    function run() external {
        console2.log("=== WAVS Register Operator ===");
        console2.log("Environment:", deployEnv);
        console2.log("Operator Address:", operatorAddress);
        console2.log("Service Manager:", serviceManagerAddress);
        console2.log("Stake Registry:", stakeRegistryAddress);
        console2.log("LST Strategy:", lstStrategyAddress);
        console2.log("LST Contract:", lstContractAddress);
        console2.log("Stake Amount:", stakeAmount);

        // Process command line arguments if any
        string[] memory args = getCliArgs();
        if (args.length > 0) {
            console2.log("Command line arguments received:", args.length);
            for (uint i = 0; i < args.length; i++) {
                console2.log(
                    string.concat("Arg ", vm.toString(i), ": ", args[i])
                );
            }

            // Try to use the second argument as stake amount if provided
            if (args.length >= 2) {
                // Check if it's "0.1" specifically
                if (keccak256(bytes(args[1])) == keccak256(bytes("0.1"))) {
                    stakeAmount = 0.1 ether;
                    console2.log("Using command line stake amount: 0.1 ETH");
                    console2.log("Amount in wei:", stakeAmount);
                } else {
                    // For other values
                    try vm.parseUint(args[1]) returns (uint256 parsed) {
                        stakeAmount = parsed * 10 ** 18; // Convert to wei
                        console2.log(
                            "Using command line stake amount:",
                            args[1],
                            "ETH"
                        );
                        console2.log("Amount in wei:", stakeAmount);
                    } catch {
                        // Keep the existing amount
                        console2.log(
                            "Failed to parse command line stake amount, using existing value"
                        );
                    }
                }
            }
        }

        // 1. Fund the operator account
        _fundOperator();

        // 2. Deposit LST tokens
        _depositLST(0, lstContractAddress, stakeAmount);

        // 3. Register as operator with delegation manager
        _registerAsDelegationOperator();

        // 4. Register for operator sets
        _registerForOperatorSets();

        // 5. Register with signature
        _registerWithSignature();

        console2.log("\nOperator registration completed successfully!");
    }

    /**
     * @notice Fund the operator account with ETH
     */
    function _fundOperator() private {
        console2.log("\n=== Funding Operator Account ===");

        vm.startBroadcast(deployerPrivateKey);

        if (keccak256(bytes(deployEnv)) == keccak256(bytes("LOCAL"))) {
            // In local mode, we can use anvil_setBalance to fund the account
            vm.setNonce(operatorAddress, 0);
            vm.deal(operatorAddress, 10 ether);
            console2.log(
                "Set operator balance to 10 ETH using anvil_setBalance"
            );
        } else {
            // In testnet mode, we need to send a transaction
            payable(operatorAddress).transfer(0.05 ether);
            console2.log("Sent 0.05 ETH to operator from deployer");
        }

        vm.stopBroadcast();

        uint256 balance = address(operatorAddress).balance;
        console2.log("Operator balance:", balance);
    }

    /**
     * @notice Deposits existing LST tokens into the strategy
     * @param strategyIndex The index of the strategy
     * @param lstContractAddress Address of the LST token contract
     * @param amount Amount to deposit
     */
    function _depositLST(
        uint256 strategyIndex,
        address lstContractAddress,
        uint256 amount
    ) internal {
        // Check existing token balance
        uint256 balance = IERC20(lstContractAddress).balanceOf(operatorAddress);
        console2.log("Current LST token balance:", balance);

        // Use the full balance for deposit regardless of the requested amount
        if (balance > 0) {
            // For safety, don't use all tokens if balance is significantly higher than requested
            if (balance > amount * 10) {
                // If balance is 10x higher than requested
                console2.log(
                    "Balance significantly exceeds requested amount. Using requested amount:",
                    amount
                );
            } else {
                // Use the entire balance
                amount = balance;
                console2.log(
                    "Using full available balance for deposit:",
                    amount
                );
            }

            // Use lstStrategyAddress directly instead of trying to get it by index
            IStrategy strategy = IStrategy(lstStrategyAddress);

            // Approve strategy manager to spend tokens
            vm.startBroadcast(operatorPrivateKey);
            IERC20(lstContractAddress).approve(strategyManagerAddress, amount);

            // Deposit into strategy
            IStrategyManager(strategyManagerAddress).depositIntoStrategy(
                strategy,
                IERC20(lstContractAddress),
                amount
            );
            vm.stopBroadcast();

            console2.log(
                "Deposited",
                amount,
                "LST tokens into strategy",
                address(strategy)
            );
        } else {
            console2.log("No LST tokens available, skipping deposit");
        }
    }

    /**
     * @notice Register as operator with delegation manager
     */
    function _registerAsDelegationOperator() private {
        console2.log("\n=== Registering as Delegation Operator ===");

        vm.startBroadcast(operatorPrivateKey);

        // Register as operator with metadata URI "foo.bar"
        IDelegationManager(delegationManagerAddress).registerAsOperator(
            operatorAddress,
            0, // Metadata type
            "foo.bar" // Metadata URI
        );
        console2.log("Registered as operator with delegation manager");

        vm.stopBroadcast();
    }

    /**
     * @notice Register for operator sets
     */
    function _registerForOperatorSets() private {
        console2.log("\n=== Registering for Operator Sets ===");

        vm.startBroadcast(operatorPrivateKey);

        // Prepare operator set IDs (just set 1 in this case)
        uint32[] memory operatorSetIds = new uint32[](1);
        operatorSetIds[0] = 1;

        // Create the RegisterParams struct as required by the interface
        IAllocationManagerTypes.RegisterParams
            memory params = IAllocationManagerTypes.RegisterParams({
                avs: serviceManagerAddress,
                operatorSetIds: operatorSetIds,
                data: hex"1234" // some arbitrary data
            });

        // Call with correct parameter structure
        IAllocationManager(allocationManagerAddress).registerForOperatorSets(
            operatorAddress,
            params
        );
        console2.log("Registered for operator sets");

        vm.stopBroadcast();
    }

    /**
     * @notice Register with signature
     */
    function _registerWithSignature() private {
        console2.log("\n=== Registering with Signature ===");

        vm.startBroadcast(operatorPrivateKey);

        // 1. Generate a random salt
        bytes32 salt = keccak256(
            abi.encodePacked(block.timestamp, operatorAddress, block.prevrandao)
        );

        // 2. Calculate expiry (current time + 1 hour)
        uint256 expiry = block.timestamp + 3600;

        // 3. Calculate digest hash
        bytes32 digestHash = IAVSDirectory(avsDirectoryAddress)
            .calculateOperatorAVSRegistrationDigestHash(
                operatorAddress,
                serviceManagerAddress,
                salt,
                expiry
            );

        // 4. Sign the digest hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            operatorPrivateKey,
            digestHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        // 5. Create signature params
        ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry
            memory signatureWithSaltAndExpiry = ISignatureUtilsMixinTypes
                .SignatureWithSaltAndExpiry({
                    signature: signature,
                    salt: salt,
                    expiry: expiry
                });

        // 6. Register with signature
        ECDSAStakeRegistry(stakeRegistryAddress).registerOperatorWithSignature(
            signatureWithSaltAndExpiry,
            operatorAddress
        );

        console2.log("Registered operator with signature");

        vm.stopBroadcast();
    }
}
