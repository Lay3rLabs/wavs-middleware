// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import {MirrorStakeRegistry} from "../src/MirrorStakeRegistry.sol";
import {IECDSAStakeRegistryTypes} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistryStorage.sol";
import {ISignatureUtilsMixinTypes} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtilsMixin.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {SignatureCheckerUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/SignatureCheckerUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MirrorStakeRegistryTest is Test {
    MirrorStakeRegistry public registry;
    address public owner;
    address public operator1;
    address public operator2;
    address public operator3;
    address public signingKey1;
    address public signingKey2;
    address public signingKey3;
    uint256 public privateKey1;
    uint256 public privateKey2;
    uint256 public privateKey3;
    address public serviceManager;
    // these should sum to around 9,0000 (so 2/3 can pass)
    uint256 public constant WEIGHT_1 = 1500;
    uint256 public constant WEIGHT_2 = 3000;
    uint256 public constant WEIGHT_3 = 4500;

    function setUp() public {
        // Set up test addresses
        owner = address(0x123);
        operator1 = address(0x1);
        operator2 = address(0x2);
        operator3 = address(0x3);
        privateKey1 = 0x11;
        privateKey2 = 0x22;
        privateKey3 = 0x33;
        signingKey1 = vm.addr(privateKey1);
        signingKey2 = vm.addr(privateKey2);
        signingKey3 = vm.addr(privateKey3);
        serviceManager = address(0x456);

        // Deploy the MirrorStakeRegistry contract
        vm.startPrank(owner);
        registry = new MirrorStakeRegistry();

        // Initialize the registry with a service manager and quorum settings
        // Create a strategy with a non-zero address to avoid the NotSorted error
        // The ECDSAStakeRegistry requires strategies to be sorted by address in ascending order
        IStrategy mockStrategyInstance = IStrategy(address(1)); // Using address(1) instead of address(0)

        // Create the strategy params
        IECDSAStakeRegistryTypes.StrategyParams memory strategyParams = IECDSAStakeRegistryTypes.StrategyParams({
            strategy: mockStrategyInstance,
            multiplier: 10000 // 100% in basis points
        });

        // Create the strategies array with one strategy
        IECDSAStakeRegistryTypes.StrategyParams[] memory strategies = new IECDSAStakeRegistryTypes.StrategyParams[](1);
        strategies[0] = strategyParams;

        // Create the quorum with the strategies
        IECDSAStakeRegistryTypes.Quorum memory quorum = IECDSAStakeRegistryTypes.Quorum({strategies: strategies});

        registry.initialize(serviceManager, 6667, quorum); // 2/3 threshold (6667 basis points)
        vm.stopPrank();
    }

    // Test that the contract is properly initialized
    function test_initialization() public view {
        assertEq(registry.owner(), owner, "Owner should be set correctly");
        assertEq(address(registry.serviceManager()), serviceManager, "Service manager should be set correctly");
    }

    // Test that public registration methods revert as expected
    function test_registrationMethodsRevert() public {
        // Test registerOperatorWithSignature reverts
        ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry memory sig;
        vm.expectRevert(MirrorStakeRegistry.RegistrationNotSupported.selector);
        registry.registerOperatorWithSignature(sig, signingKey1);

        // Test deregisterOperator reverts
        vm.expectRevert(MirrorStakeRegistry.DeregistrationNotSupported.selector);
        registry.deregisterOperator();

        // Test updateOperatorSigningKey reverts
        vm.expectRevert(MirrorStakeRegistry.SigningKeyUpdateNotSupported.selector);
        registry.updateOperatorSigningKey(signingKey1);

        // Test updateOperators reverts
        address[] memory operators = new address[](1);
        operators[0] = operator1;
        vm.expectRevert(MirrorStakeRegistry.OperatorUpdateNotSupported.selector);
        registry.updateOperators(operators);

        // Test updateOperatorsForQuorum reverts
        address[][] memory operatorsArray = new address[][](1);
        operatorsArray[0] = operators;
        bytes memory extraData = "";
        vm.expectRevert(MirrorStakeRegistry.QuorumOperatorUpdateNotSupported.selector);
        registry.updateOperatorsForQuorum(operatorsArray, extraData);
    }

    // Test that owner-only configuration methods revert as expected
    function test_ownerConfigMethodsRevert() public {
        vm.startPrank(owner);

        // Test updateQuorumConfig reverts
        IECDSAStakeRegistryTypes.StrategyParams[] memory strategyParamsArray =
            new IECDSAStakeRegistryTypes.StrategyParams[](0);
        IECDSAStakeRegistryTypes.Quorum memory quorum =
            IECDSAStakeRegistryTypes.Quorum({strategies: strategyParamsArray});
        address[] memory operators = new address[](1);
        operators[0] = operator1;
        vm.expectRevert(MirrorStakeRegistry.QuorumOperatorUpdateNotSupported.selector);
        registry.updateQuorumConfig(quorum, operators);

        // Test updateMinimumWeight reverts
        vm.expectRevert(MirrorStakeRegistry.OperatorUpdateNotSupported.selector);
        registry.updateMinimumWeight(200, operators);

        vm.stopPrank();
    }

    // Test that non-owners cannot call owner-only methods
    function test_onlyOwnerRestriction() public {
        vm.startPrank(address(0x999)); // Not the owner

        // Test setOperatorDetails reverts for non-owners
        vm.expectRevert("Ownable: caller is not the owner");
        registry.setOperatorDetails(operator1, signingKey1, WEIGHT_1);

        // Test batchSetOperatorDetails reverts for non-owners
        address[] memory operators = new address[](1);
        address[] memory signingKeys = new address[](1);
        uint256[] memory weights = new uint256[](1);
        operators[0] = operator1;
        signingKeys[0] = signingKey1;
        weights[0] = WEIGHT_1;

        vm.expectRevert("Ownable: caller is not the owner");
        registry.batchSetOperatorDetails(operators, signingKeys, weights);

        vm.stopPrank();
    }

    // Test setting operator details by the owner
    function test_setOperatorDetails() public {
        vm.startPrank(owner);

        // Set operator details
        registry.setOperatorDetails(operator1, signingKey1, WEIGHT_1);

        // Verify the operator weight is set correctly
        assertEq(registry.getOperatorWeight(operator1), WEIGHT_1, "Operator weight should be set correctly");

        // Verify the signing key is associated with the operator
        assertEq(registry.getLatestOperatorSigningKey(operator1), signingKey1, "Signing key should be set correctly");

        // Verify the operator is associated with the signing key
        assertEq(
            registry.getLatestOperatorForSigningKey(signingKey1),
            operator1,
            "Operator should be associated with signing key"
        );

        vm.stopPrank();
    }

    // Test batch setting operator details by the owner
    function test_batchSetOperatorDetails() public {
        vm.startPrank(owner);

        // Set up batch data
        address[] memory operators = new address[](3);
        address[] memory signingKeys = new address[](3);
        uint256[] memory weights = new uint256[](3);

        operators[0] = operator1;
        operators[1] = operator2;
        operators[2] = operator3;

        signingKeys[0] = signingKey1;
        signingKeys[1] = signingKey2;
        signingKeys[2] = signingKey3;

        weights[0] = WEIGHT_1;
        weights[1] = WEIGHT_2;
        weights[2] = WEIGHT_3;

        // Batch set operator details
        registry.batchSetOperatorDetails(operators, signingKeys, weights);

        // Verify all operators' weights are set correctly
        assertEq(registry.getOperatorWeight(operator1), WEIGHT_1, "Operator1 weight should be set correctly");
        assertEq(registry.getOperatorWeight(operator2), WEIGHT_2, "Operator2 weight should be set correctly");
        assertEq(registry.getOperatorWeight(operator3), WEIGHT_3, "Operator3 weight should be set correctly");

        // Verify all signing keys are associated with their operators
        assertEq(registry.getLatestOperatorSigningKey(operator1), signingKey1, "Signing key1 should be set correctly");
        assertEq(registry.getLatestOperatorSigningKey(operator2), signingKey2, "Signing key2 should be set correctly");
        assertEq(registry.getLatestOperatorSigningKey(operator3), signingKey3, "Signing key3 should be set correctly");

        // Verify all operators are associated with their signing keys
        assertEq(
            registry.getLatestOperatorForSigningKey(signingKey1),
            operator1,
            "Operator1 should be associated with signing key1"
        );
        assertEq(
            registry.getLatestOperatorForSigningKey(signingKey2),
            operator2,
            "Operator2 should be associated with signing key2"
        );
        assertEq(
            registry.getLatestOperatorForSigningKey(signingKey3),
            operator3,
            "Operator3 should be associated with signing key3"
        );

        vm.stopPrank();
    }

    // Test updating an existing operator's details
    function test_updateExistingOperator() public {
        vm.startPrank(owner);

        // Set initial operator details
        registry.setOperatorDetails(operator1, signingKey1, WEIGHT_1);

        // Update operator with new signing key and weight
        address newSigningKey = address(0x111);
        uint256 newWeight = 150;
        registry.setOperatorDetails(operator1, newSigningKey, newWeight);

        // Verify the operator weight is updated
        assertEq(registry.getOperatorWeight(operator1), newWeight, "Operator weight should be updated");

        // Verify the new signing key is associated with the operator
        assertEq(registry.getLatestOperatorSigningKey(operator1), newSigningKey, "New signing key should be set");

        // Verify the old signing key is no longer associated with the operator
        assertEq(
            registry.getLatestOperatorForSigningKey(signingKey1), address(0), "Old signing key should not be associated"
        );

        // Verify the operator is associated with the new signing key
        assertEq(
            registry.getLatestOperatorForSigningKey(newSigningKey),
            operator1,
            "Operator should be associated with new signing key"
        );

        vm.stopPrank();
    }

    // Test batch input validation for mismatched array lengths
    function test_batchSetOperatorDetails_mismatchedArrays() public {
        vm.startPrank(owner);

        // Set up batch data with mismatched array lengths
        address[] memory operators = new address[](3);
        address[] memory signingKeys = new address[](2); // One less than operators
        uint256[] memory weights = new uint256[](3);

        operators[0] = operator1;
        operators[1] = operator2;
        operators[2] = operator3;

        signingKeys[0] = signingKey1;
        signingKeys[1] = signingKey2;

        weights[0] = WEIGHT_1;
        weights[1] = WEIGHT_2;
        weights[2] = WEIGHT_3;

        // Expect revert due to mismatched array lengths
        vm.expectRevert(MirrorStakeRegistry.InvalidArrayLengths.selector);
        registry.batchSetOperatorDetails(operators, signingKeys, weights);

        // Try another mismatch
        signingKeys = new address[](3); // Now correct
        weights = new uint256[](2); // Now this is wrong

        signingKeys[0] = signingKey1;
        signingKeys[1] = signingKey2;
        signingKeys[2] = signingKey3;

        weights[0] = WEIGHT_1;
        weights[1] = WEIGHT_2;

        // Expect revert due to mismatched array lengths
        vm.expectRevert(MirrorStakeRegistry.InvalidArrayLengths.selector);
        registry.batchSetOperatorDetails(operators, signingKeys, weights);

        vm.stopPrank();
    }

    // Test getting operator weight at block
    function test_getOperatorWeightAtBlock() public {
        vm.startPrank(owner);

        // Set operator details
        registry.setOperatorDetails(operator1, signingKey1, WEIGHT_1);

        // We need to roll to the next block to make the checkpoint available
        vm.roll(block.number + 1);

        // Now we can get the weight at the previous block
        uint32 previousBlock = uint32(block.number - 1);

        // Verify the operator weight at the previous block
        assertEq(
            registry.getOperatorWeightAtBlock(operator1, previousBlock),
            WEIGHT_1,
            "Operator weight at block should be correct"
        );

        vm.stopPrank();
    }

    // Test getting total weight
    function test_getTotalWeight() public {
        vm.startPrank(owner);

        // Set up batch data
        address[] memory operators = new address[](3);
        address[] memory signingKeys = new address[](3);
        uint256[] memory weights = new uint256[](3);

        operators[0] = operator1;
        operators[1] = operator2;
        operators[2] = operator3;

        signingKeys[0] = signingKey1;
        signingKeys[1] = signingKey2;
        signingKeys[2] = signingKey3;

        weights[0] = WEIGHT_1;
        weights[1] = WEIGHT_2;
        weights[2] = WEIGHT_3;

        // Batch set operator details
        registry.batchSetOperatorDetails(operators, signingKeys, weights);

        // Calculate expected total weight
        uint256 expectedTotalWeight = WEIGHT_1 + WEIGHT_2 + WEIGHT_3;

        // Verify the total weight
        assertEq(registry.getLastCheckpointTotalWeight(), expectedTotalWeight, "Total weight should be correct");

        // We need to roll to the next block to make the checkpoint available
        vm.roll(block.number + 1);

        // Now we can get the weight at the previous block
        uint32 previousBlock = uint32(block.number - 1);

        // Verify the total weight at the previous block
        assertEq(
            registry.getLastCheckpointTotalWeightAtBlock(previousBlock),
            expectedTotalWeight,
            "Total weight at block should be correct"
        );

        vm.stopPrank();
    }

    /**
     * @notice Helper function to sort signers and their corresponding signatures in ascending order by signer address
     * @dev ECDSAStakeRegistry requires signers to be sorted in ascending order
     * @param signers Array of signer addresses
     * @param signatures Array of signatures that correspond to signers at the same index
     */
    function sortSignersAndSignatures(address[] memory signers, bytes[] memory signatures) internal pure {
        // Simple bubble sort since we're working with small arrays
        uint256 length = signers.length;
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                if (signers[j] > signers[j + 1]) {
                    // Swap signers
                    address tempAddr = signers[j];
                    signers[j] = signers[j + 1];
                    signers[j + 1] = tempAddr;

                    // Swap corresponding signatures
                    bytes memory tempSig = signatures[j];
                    signatures[j] = signatures[j + 1];
                    signatures[j + 1] = tempSig;
                }
            }
        }
    }

    /**
     * @notice Helper function to generate an ECDSA signature using a private key
     * @param privateKey The private key to sign with
     * @param digest The message hash to sign
     * @return The signature in bytes format ready for validation
     */
    function generateSignature(uint256 privateKey, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    /**
     * @notice Helper function to verify that signatures can be recovered to the expected signers
     * @param digest Message hash that was signed
     * @param signers Array of signer addresses (should be sorted)
     * @param signatures Array of signatures corresponding to signers
     */
    function verifySignatures(bytes32 digest, address[] memory signers, bytes[] memory signatures) internal pure {
        require(signers.length == signatures.length, "Arrays length mismatch");

        for (uint256 i = 0; i < signers.length; i++) {
            address recovered = ECDSA.recover(digest, signatures[i]);
            require(recovered == signers[i], "Signature recovery failed");
        }
    }

    // Test isValidSignature functionality with real signatures
    function test_isValidSignature() public {
        vm.startPrank(owner);

        // Set up operators with weights
        address[] memory operators = new address[](3);
        address[] memory signingKeys = new address[](3);
        uint256[] memory weights = new uint256[](3);

        operators[0] = operator1;
        operators[1] = operator2;
        operators[2] = operator3;

        signingKeys[0] = signingKey1;
        signingKeys[1] = signingKey2;
        signingKeys[2] = signingKey3;

        weights[0] = WEIGHT_1;
        weights[1] = WEIGHT_2;
        weights[2] = WEIGHT_3;

        // Batch set operator details
        registry.batchSetOperatorDetails(operators, signingKeys, weights);
        vm.stopPrank();

        // Create a message to sign
        bytes32 digest = keccak256("test message");

        // Roll to the next block to make the checkpoint available
        vm.roll(block.number + 1);

        // Create signature data for all signing keys
        address[] memory signers = new address[](3);
        bytes[] memory signatures = new bytes[](3);
        uint32 referenceBlock = uint32(block.number - 1); // Use the previous block as reference

        // Add signing keys to signers array
        signers[0] = signingKey1;
        signers[1] = signingKey2;
        signers[2] = signingKey3;

        // Generate actual signatures using the private keys
        signatures[0] = generateSignature(privateKey1, digest);
        signatures[1] = generateSignature(privateKey2, digest);
        signatures[2] = generateSignature(privateKey3, digest);

        // Sort the signers and signatures arrays to ensure signers are in ascending order
        // ECDSAStakeRegistry requires this for validation
        sortSignersAndSignatures(signers, signatures);

        // Verify signers are properly sorted
        for (uint256 i = 0; i < signers.length - 1; i++) {
            assertTrue(signers[i] < signers[i + 1], "Signers not properly sorted");
        }

        // Verify our signatures are valid and match the expected signers
        verifySignatures(digest, signers, signatures);

        // Encode the signature data as expected by isValidSignature
        bytes memory signatureData = abi.encode(signers, signatures, referenceBlock);

        // Call isValidSignature with real signatures
        bytes4 result = registry.isValidSignature(digest, signatureData);

        // Verify the result
        assertEq(
            result, IERC1271Upgradeable.isValidSignature.selector, "isValidSignature should return the correct selector"
        );
    }
}
