// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ECDSAUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";

import {WavsMirrorDeploymentLib} from "script/eigenlayer/ecdsa/utils/WavsMirrorDeploymentLib.sol";
import {UpgradeableProxyLib} from "script/eigenlayer/ecdsa/utils/UpgradeableProxyLib.sol";
import {MirrorStakeRegistry} from "src/eigenlayer/ecdsa/MirrorStakeRegistry.sol";
import {WavsServiceManager} from "src/eigenlayer/ecdsa/WavsServiceManager.sol";
import {
    MirrorOperatorSyncHandler,
    IMirrorOperatorSyncHandler
} from "src/eigenlayer/ecdsa/handlers/MirrorOperatorSyncHandler.sol";
import {IWavsServiceHandler} from "src/eigenlayer/ecdsa/interfaces/IWavsServiceHandler.sol";

/**
 * @title MirrorOperatorSyncHandlerTest
 * @author Lay3rLabs
 * @notice This contract contains tests for the MirrorOperatorSyncHandler contract.
 * @dev This contract is used to test the MirrorOperatorSyncHandler contract.
 */
contract MirrorOperatorSyncHandlerTest is Test {
    using UpgradeableProxyLib for address;

    // Constants
    uint256 private constant OPERATOR_WEIGHT = 10_000;

    address private deployer;
    address private proxyAdmin;

    // Contract references
    MirrorStakeRegistry private stakeRegistry;
    WavsServiceManager private serviceManager;
    MirrorOperatorSyncHandler private serviceHandler;

    // Basic operator data
    address[] private operators;
    address[] private signingKeyAddresses;
    uint256[] private weights;
    uint256[] private privateKeys;

    error MirrorOperatorSyncHandlerTest__BlockNumberTooLowForOffset();
    error MirrorOperatorSyncHandlerTest__ArraysLengthMismatch();
    error MirrorOperatorSyncHandlerTest__SignatureRecoveryFailed();

    /// @notice The setUp function.
    function setUp() public {
        // Set up deployer address
        deployer = address(0x123);
        vm.startPrank(deployer);

        // Deploy proxy admin
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        // Deploy contracts
        WavsMirrorDeploymentLib.DeploymentData memory deployment =
            WavsMirrorDeploymentLib.deployContracts(proxyAdmin);

        // Create references to deployed contracts
        serviceManager = WavsServiceManager(deployment.wavsServiceManager);
        stakeRegistry = MirrorStakeRegistry(deployment.stakeRegistry);

        vm.stopPrank();

        // Create test info for 5 operators
        privateKeys = new uint256[](5);
        operators = new address[](5);
        signingKeyAddresses = new address[](5);
        weights = new uint256[](5);

        for (uint256 i = 0; i < 5; ++i) {
            privateKeys[i] = i + 1;
            operators[i] = vm.addr(privateKeys[i]);
            signingKeyAddresses[i] = vm.addr(privateKeys[i]);
            weights[i] = OPERATOR_WEIGHT;
        }

        // Find out the actual owner of the contracts
        address actualOwner = serviceManager.owner();

        // Set up test operator weights as the actual owner
        vm.startPrank(actualOwner);
        stakeRegistry.batchSetOperatorDetails(operators, signingKeyAddresses, weights);
        vm.stopPrank();

        // Deploy MirrorOperatorSyncHandler
        vm.startPrank(actualOwner);
        deployment = WavsMirrorDeploymentLib.deployServiceHandlers(deployment);
        serviceHandler = MirrorOperatorSyncHandler(deployment.operatorSyncHandler);
        vm.stopPrank();

        // Roll to block 10 to ensure we have enough blocks for reference blocks
        vm.roll(10);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_initial_state function.
    function test_initial_state() public view {
        /* solhint-enable func-name-mixedcase */
        // Verify deployment addresses are set correctly
        assertNotEq(address(serviceHandler), address(0), "ServiceHandler address cannot be zero");

        // Verify contract references
        assertEq(
            address(serviceHandler.getStakeRegistry()),
            address(stakeRegistry),
            "ServiceHandler should reference correct StakeRegistry"
        );

        assertEq(
            address(serviceHandler.getServiceManager()),
            address(serviceManager),
            "ServiceHandler should reference correct ServiceManager"
        );

        // Verify initial trigger ID is 0
        assertEq(serviceHandler.lastTriggerId(), 0, "Initial trigger ID should be 0");

        // Verify that the owner of the stakeRegistry is the serviceHandler
        assertEq(
            stakeRegistry.owner(),
            address(serviceHandler),
            "ServiceHandler should be the owner of stakeRegistry"
        );
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_invalid_payload function.
    function test_invalid_payload() public {
        /* solhint-enable func-name-mixedcase */
        // Create an envelope with invalid payload
        IWavsServiceHandler.Envelope memory envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(1)),
            ordering: bytes12(0),
            payload: abi.encode("Bad payload")
        });

        // Create signature data with 4 operators (more than enough to pass quorum)
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 4, 5);

        // Call handleSignedEnvelope should fail with invalid payload
        vm.expectRevert();
        serviceHandler.handleSignedEnvelope(envelope, signatureData);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_invalid_trigger_id function.
    function test_invalid_trigger_id() public {
        /* solhint-enable func-name-mixedcase */
        // Keep the same operators
        address[] memory newOperators = operators;
        address[] memory newSigningKeyAddresses = signingKeyAddresses;
        uint256[] memory newWeights = weights;

        // Update to triggerId 5
        IMirrorOperatorSyncHandler.UpdateWithId memory updateData = IMirrorOperatorSyncHandler
            .UpdateWithId({
            triggerId: 5,
            thresholdWeight: 5000,
            operators: newOperators,
            signingKeyAddresses: newSigningKeyAddresses,
            weights: newWeights
        });
        // Create envelope with the encoded payload
        IWavsServiceHandler.Envelope memory envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(1)),
            ordering: bytes12(0),
            payload: abi.encode(updateData)
        });

        // Create signature data with 4 operators (more than enough to pass quorum)
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 4, 5);
        // Will pass and update to 5
        serviceHandler.handleSignedEnvelope(envelope, signatureData);

        // ensure it is updated
        assertEq(serviceHandler.lastTriggerId(), 5, "Initial trigger ID should be 5");

        // Try again will fail (reply)
        vm.expectRevert(
            abi.encodeWithSelector(IMirrorOperatorSyncHandler.InvalidTriggerId.selector, 5)
        );
        serviceHandler.handleSignedEnvelope(envelope, signatureData);

        // Previous trigger id will fail
        updateData = IMirrorOperatorSyncHandler.UpdateWithId({
            triggerId: 3, // 3 < 5
            thresholdWeight: 5000,
            operators: newOperators,
            signingKeyAddresses: newSigningKeyAddresses,
            weights: newWeights
        });
        // Create envelope with the encoded payload
        envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(2)),
            ordering: bytes12(0),
            payload: abi.encode(updateData)
        });
        // Create signature data with 4 operators (more than enough to pass quorum)
        signatureData = createSignatureData(envelope, 4, 5);

        // but fails
        vm.expectRevert(
            abi.encodeWithSelector(IMirrorOperatorSyncHandler.InvalidTriggerId.selector, 5)
        );
        serviceHandler.handleSignedEnvelope(envelope, signatureData);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_insufficient_quorum function.
    function test_insufficient_quorum() public {
        /* solhint-enable func-name-mixedcase */
        // Create a valid UpdateWithId payload with triggerId = 1
        address[] memory newOperators = new address[](1);
        address[] memory newSigningKeyAddresses = new address[](1);
        uint256[] memory newWeights = new uint256[](1);

        newOperators[0] = address(0x123);
        newSigningKeyAddresses[0] = address(0x456);
        newWeights[0] = 10_000;

        // Create the UpdateWithId struct with triggerId = 1
        IMirrorOperatorSyncHandler.UpdateWithId memory updateData = IMirrorOperatorSyncHandler
            .UpdateWithId({
            triggerId: 1,
            thresholdWeight: 5000,
            operators: newOperators,
            signingKeyAddresses: newSigningKeyAddresses,
            weights: newWeights
        });

        // Create envelope with the encoded payload
        IWavsServiceHandler.Envelope memory envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(1)),
            ordering: bytes12(0),
            payload: abi.encode(updateData)
        });

        // Create signature data with only 3 operators (not enough for quorum)
        // The quorum is 4/5 (80%) in the default setup
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 3, 5);

        // Call handleSignedEnvelope should fail with InsufficientQuorum
        // Note: The actual error will come from the serviceManager.validate() call inside handleSignedEnvelope
        // which will revert with InsufficientQuorum error
        // The actual values are slightly different due to integer division in the contract
        vm.expectRevert(
            abi.encodeWithSignature(
                "InsufficientQuorum(uint256,uint256,uint256)",
                30_000, // 3/5 * 10000 = 6000 (but in basis points, so 30000)
                33_333, // 1/3 in basis points (rounded up from 33333.33...)
                50_000 // 1/2 in basis points (due to integer math in the contract)
            )
        );
        serviceHandler.handleSignedEnvelope(envelope, signatureData);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_successful_update_weight function.
    function test_successful_update_weight() public {
        /* solhint-enable func-name-mixedcase */
        // let's change the weights and a public key
        // now op1 and op2 have 2/3 and can pass a future round
        address[] memory newOperators = new address[](2);
        address[] memory newSigningKeyAddresses = new address[](2);
        uint256[] memory newWeights = new uint256[](2);

        // after this, we have 30k, 30k, 10k, 10k, 10k
        for (uint256 i = 0; i < 2; ++i) {
            newOperators[i] = operators[i];
            newSigningKeyAddresses[i] = signingKeyAddresses[i];
            newWeights[i] = OPERATOR_WEIGHT * 3;
        }

        // Create the UpdateWithId struct with triggerId = 1
        IMirrorOperatorSyncHandler.UpdateWithId memory updateData = IMirrorOperatorSyncHandler
            .UpdateWithId({
            triggerId: 1,
            thresholdWeight: 8000,
            operators: newOperators,
            signingKeyAddresses: newSigningKeyAddresses,
            weights: newWeights
        });

        // Create envelope with the encoded payload
        IWavsServiceHandler.Envelope memory envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(1)),
            ordering: bytes12(0),
            payload: abi.encode(updateData)
        });

        // 4/5 can pass this with > 2/3
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 4, 0);
        serviceHandler.handleSignedEnvelope(envelope, signatureData);

        // Check that the lastTriggerId was incremented
        assertEq(
            stakeRegistry.getLastCheckpointThresholdWeight(), 8000, "stakeThreshold not updated"
        );
        assertEq(serviceHandler.lastTriggerId(), 1, "lastTriggerId not incremented");

        // Move forward in blocks to ensure the previous update is finalized
        uint256 startBlock = vm.getBlockNumber();
        uint256 stepOne = startBlock + 10;
        vm.roll(stepOne + 1);

        // Check the weights were updated at the block of the first update
        for (uint256 i = 0; i < 2; ++i) {
            uint256 weight =
                stakeRegistry.getOperatorWeightAtBlock(newOperators[i], uint32(stepOne));
            assertEq(weight, newWeights[i], "Operator weight not updated");
        }

        uint256 totalWeight = stakeRegistry.getLastCheckpointTotalWeightAtBlock(uint32(stepOne));
        assertEq(totalWeight, 90_000, "Total weight not updated");

        newOperators = new address[](3);
        newSigningKeyAddresses = new address[](3);
        newWeights = new uint256[](3);

        // Set up the next update - setting weights to 0 for the last 3 operators
        for (uint256 i = 0; i < 3; ++i) {
            newOperators[i] = operators[i + 2];
            newSigningKeyAddresses[i] = signingKeyAddresses[i + 2];
            newWeights[i] = 0;
        }

        // Create the UpdateWithId struct with triggerId = 2
        updateData = IMirrorOperatorSyncHandler.UpdateWithId({
            triggerId: 2,
            thresholdWeight: 6500,
            operators: newOperators,
            signingKeyAddresses: newSigningKeyAddresses,
            weights: newWeights
        });

        // Create envelope with the encoded payload
        envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(1)),
            ordering: bytes12(0),
            payload: abi.encode(updateData)
        });

        // First 2 operators now have 2/3 and can pass
        signatureData = createSignatureData(envelope, 2, 0);

        // Call handleSignedEnvelope
        serviceHandler.handleSignedEnvelope(envelope, signatureData);

        // Move forward in blocks to ensure the previous update is finalized
        uint256 stepTwo = startBlock + 20;
        vm.roll(stepTwo + 1);

        // Check that the lastTriggerId was incremented
        assertEq(
            stakeRegistry.getLastCheckpointThresholdWeight(), 6500, "stakeThreshold not updated"
        );
        assertEq(serviceHandler.lastTriggerId(), 2, "lastTriggerId not incremented to 2");

        uint256 newTotalWeight = stakeRegistry.getLastCheckpointTotalWeightAtBlock(uint32(stepTwo));
        assertEq(newTotalWeight, 60_000, "Total weight not updated");

        // Check that the operator weights were properly updated (0s for the other operators)
        for (uint256 i = 0; i < 3; ++i) {
            uint256 weight =
                stakeRegistry.getOperatorWeightAtBlock(newOperators[i], uint32(stepTwo));
            assertEq(weight, 0, "Operator weight not set to 0");
        }
    }

    /**
     * @notice The createSignatureData function.
     * @param envelope The envelope.
     * @param numOperators The number of operators.
     * @param referenceBlockOffset The reference block offset.
     * @return The signature data.
     */
    function createSignatureData(
        IWavsServiceHandler.Envelope memory envelope,
        uint256 numOperators,
        uint32 referenceBlockOffset
    ) internal view returns (IWavsServiceHandler.SignatureData memory) {
        // Create digest using the same logic as WavsServiceManager
        bytes32 message = keccak256(abi.encode(envelope));
        bytes32 digest = ECDSAUpgradeable.toEthSignedMessageHash(message);

        // Create signature data with the desired number of signers
        address[] memory signers = new address[](numOperators);
        bytes[] memory signatures = new bytes[](numOperators);

        for (uint256 i = 0; i < numOperators; ++i) {
            // Generate signer address from private key
            signers[i] = vm.addr(privateKeys[i]);

            // Generate signature using private key
            signatures[i] = generateSignature(privateKeys[i], digest);
        }

        // Sort signers and signatures by signer address11
        sortSignersAndSignatures(signers, signatures);

        // Verify signatures
        verifySignatures(digest, signers, signatures);

        // Create signature data
        // Note: referenceBlock must be a valid block that exists and is in the past
        // Make sure we're at least at block 1 before subtracting offset
        uint32 currentBlock = uint32(block.number);
        if (!(currentBlock > referenceBlockOffset)) {
            revert MirrorOperatorSyncHandlerTest__BlockNumberTooLowForOffset();
        }

        return IWavsServiceHandler.SignatureData({
            signers: signers,
            signatures: signatures,
            referenceBlock: currentBlock - 1 - referenceBlockOffset
        });
    }

    /**
     * @notice The sortSignersAndSignatures function.
     * @dev ECDSAStakeRegistry requires signers to be sorted in ascending order
     * @param signers Array of signer addresses
     * @param signatures Array of signatures that correspond to signers at the same index
     */
    function sortSignersAndSignatures(
        address[] memory signers,
        bytes[] memory signatures
    ) internal pure {
        // Simple bubble sort since we're working with small arrays
        uint256 length = signers.length;
        for (uint256 i = 0; i < length - 1; ++i) {
            for (uint256 j = 0; j < length - i - 1; ++j) {
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
     * @notice The generateSignature function.
     * @param privateKey The private key to sign with
     * @param digest The message hash to sign
     * @return The signature in bytes format ready for validation
     */
    function generateSignature(
        uint256 privateKey,
        bytes32 digest
    ) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    /**
     * @notice The verifySignatures function.
     * @param digest Message hash that was signed
     * @param signers Array of signer addresses (should be sorted)
     * @param signatures Array of signatures corresponding to signers
     */
    function verifySignatures(
        bytes32 digest,
        address[] memory signers,
        bytes[] memory signatures
    ) internal pure {
        if (signers.length != signatures.length) {
            revert MirrorOperatorSyncHandlerTest__ArraysLengthMismatch();
        }

        for (uint256 i = 0; i < signers.length; ++i) {
            address recovered = ECDSA.recover(digest, signatures[i]);
            if (recovered != signers[i]) {
                revert MirrorOperatorSyncHandlerTest__SignatureRecoveryFailed();
            }
        }
    }
}
