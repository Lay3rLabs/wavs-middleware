// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {
    ECDSAUpgradeable
} from "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";

import {WavsMirrorDeploymentLib} from "script/eigenlayer/ecdsa/utils/WavsMirrorDeploymentLib.sol";
import {UpgradeableProxyLib} from "script/eigenlayer/ecdsa/utils/UpgradeableProxyLib.sol";
import {MirrorStakeRegistry} from "src/eigenlayer/ecdsa/MirrorStakeRegistry.sol";
import {WavsServiceManager} from "src/eigenlayer/ecdsa/WavsServiceManager.sol";
import {
    MirrorQuorumSyncHandler,
    IMirrorQuorumSyncHandler
} from "src/eigenlayer/ecdsa/handlers/MirrorQuorumSyncHandler.sol";
import {IWavsServiceHandler} from "src/eigenlayer/ecdsa/interfaces/IWavsServiceHandler.sol";

/**
 * @title MirrorQuorumSyncHandlerTest
 * @author Lay3rLabs
 * @notice This contract contains tests for the MirrorQuorumSyncHandler contract.
 * @dev This contract is used to test the MirrorQuorumSyncHandler contract.
 */
contract MirrorQuorumSyncHandlerTest is Test {
    using UpgradeableProxyLib for address;

    // Constants
    uint256 private constant OPERATOR_WEIGHT = 10_000;

    address private deployer;
    address private proxyAdmin;
    WavsMirrorDeploymentLib.DeploymentData private deployment;

    // Contract references
    MirrorStakeRegistry private stakeRegistry;
    WavsServiceManager private serviceManager;
    MirrorQuorumSyncHandler private serviceHandler;

    // Basic operator data
    address[] private operators;
    address[] private signingKeyAddresses;
    uint256[] private weights;
    uint256[] private privateKeys;

    /// @notice The error for the block number too low for offset.
    error MirrorQuorumSyncHandlerTest__BlockNumberTooLowForOffset();
    /// @notice The error for the arrays length mismatch.
    error MirrorQuorumSyncHandlerTest__ArraysLengthMismatch();
    /// @notice The error for the signature recovery failed.
    error MirrorQuorumSyncHandlerTest__SignatureRecoveryFailed();

    /// @notice The setUp function.
    function setUp() public {
        // Set up deployer address
        deployer = address(0x123);
        vm.startPrank(deployer);

        // Deploy proxy admin
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        // Deploy contracts
        deployment = WavsMirrorDeploymentLib.deployContracts(proxyAdmin);

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

        // Deploy MirrorQuorumSyncHandler
        vm.startPrank(actualOwner);
        deployment = WavsMirrorDeploymentLib.deployServiceHandlers(deployment);
        serviceHandler = MirrorQuorumSyncHandler(deployment.quorumSyncHandler);
        vm.stopPrank();

        // Roll to block 10 to ensure we have enough blocks for reference blocks
        vm.roll(10);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_initial_state function.
    function test_initial_state() public view {
        /* solhint-enable func-name-mixedcase */
        // Test initial state of the service handler
        assertEq(serviceHandler.lastTriggerId(), 0, "Initial trigger ID should be 0");
        assertEq(
            address(serviceHandler.getServiceManager()),
            address(serviceManager),
            "Service manager address should be set"
        );
        assertEq(serviceManager.quorumNumerator(), 2, "Initial quorum numerator should be 2");
        assertEq(serviceManager.quorumDenominator(), 3, "Initial quorum denominator should be 3");
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_invalid_trigger_id function.
    function test_invalid_trigger_id() public {
        /* solhint-enable func-name-mixedcase */
        // update trigger to 5
        IMirrorQuorumSyncHandler.UpdateWithId memory updateData =
            IMirrorQuorumSyncHandler.UpdateWithId({triggerId: 5, numerator: 2, denominator: 3});
        // Create envelope with the encoded payload
        IWavsServiceHandler.Envelope memory envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(1)), ordering: bytes12(0), payload: abi.encode(updateData)
        });

        // Create signature data with all operators (5/5)
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 5, 0);
        // Passes first time
        serviceHandler.handleSignedEnvelope(envelope, signatureData);

        // Replay should fail with InvalidTriggerId
        vm.expectRevert(
            abi.encodeWithSelector(IMirrorQuorumSyncHandler.InvalidTriggerId.selector, 5)
        );
        serviceHandler.handleSignedEnvelope(envelope, signatureData);

        // Try lower trigger id (2) to show it fails
        updateData =
            IMirrorQuorumSyncHandler.UpdateWithId({triggerId: 2, numerator: 3, denominator: 4});
        // Create envelope with the encoded payload
        envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(2)), ordering: bytes12(0), payload: abi.encode(updateData)
        });
        // Create signature data with all operators (5/5)
        signatureData = createSignatureData(envelope, 5, 0);

        // Previous id should fail with InvalidTriggerId
        vm.expectRevert(
            abi.encodeWithSelector(IMirrorQuorumSyncHandler.InvalidTriggerId.selector, 5)
        );
        serviceHandler.handleSignedEnvelope(envelope, signatureData);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_insufficient_quorum function.
    function test_insufficient_quorum() public {
        /* solhint-enable func-name-mixedcase */
        // Create a valid UpdateWithId payload with triggerId = 1
        IMirrorQuorumSyncHandler.UpdateWithId memory updateData =
            IMirrorQuorumSyncHandler.UpdateWithId({triggerId: 1, numerator: 2, denominator: 3});

        // Create envelope with the encoded payload
        IWavsServiceHandler.Envelope memory envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(1)), ordering: bytes12(0), payload: abi.encode(updateData)
        });

        // Create signature data with only 2 operators (not enough for quorum)
        // The quorum is 3/5 (60%) in the default setup
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 2, 0);

        // Call handleSignedEnvelope should fail with InsufficientQuorum
        vm.expectRevert(
            abi.encodeWithSignature(
                "InsufficientQuorum(uint256,uint256,uint256)",
                20_000, // has
                33_333, // needs
                50_000 // max
            )
        );
        serviceHandler.handleSignedEnvelope(envelope, signatureData);
    }

    /*
    // TODO: no error on parse. how to validate?
    function test_invalid_payload() public {
        // Create an invalid payload (not matching UpdateWithId struct)
        bytes memory invalidPayload = abi.encode("BAD");

        // Create envelope with the invalid payload
        IWavsServiceHandler.Envelope memory envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(1)),
            ordering: bytes12(0),
            payload: invalidPayload
        });

        // Create signature data with all operators (5/5)
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 5, 5);

        // Call handleSignedEnvelope should fail with abi decode error
        vm.expectRevert(); // Decoding error
        serviceHandler.handleSignedEnvelope(envelope, signatureData);
    }
    */

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_successful_update_quorum function.
    function test_successful_update_quorum() public {
        /* solhint-enable func-name-mixedcase */
        // let's change quorum so 2/5 (4/10)can pass, not 2/3
        // Create the UpdateWithId struct with triggerId = 1
        IMirrorQuorumSyncHandler.UpdateWithId memory updateData =
            IMirrorQuorumSyncHandler.UpdateWithId({triggerId: 1, numerator: 4, denominator: 10});

        // Create envelope with the encoded payload
        IWavsServiceHandler.Envelope memory envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(1)), ordering: bytes12(0), payload: abi.encode(updateData)
        });

        // 4/5 can pass this with > 2/3
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 4, 0);
        serviceHandler.handleSignedEnvelope(envelope, signatureData);

        // Check that the lastTriggerId was incremented
        assertEq(serviceHandler.lastTriggerId(), 1, "lastTriggerId not incremented");
        assertEq(serviceManager.quorumNumerator(), 4, "Initial quorum numerator should be 4");
        assertEq(serviceManager.quorumDenominator(), 10, "Initial quorum denominator should be 10");

        updateData =
            IMirrorQuorumSyncHandler.UpdateWithId({triggerId: 2, numerator: 1, denominator: 6});

        // Create envelope with the encoded payload
        envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(1)), ordering: bytes12(0), payload: abi.encode(updateData)
        });

        // 2/5 is now enough to pass
        signatureData = createSignatureData(envelope, 2, 0);
        serviceHandler.handleSignedEnvelope(envelope, signatureData);

        // Check that the lastTriggerId was incremented
        assertEq(serviceHandler.lastTriggerId(), 2, "lastTriggerId not incremented to 2");
        assertEq(serviceManager.quorumNumerator(), 1, "Initial quorum numerator should be 1");
        assertEq(serviceManager.quorumDenominator(), 6, "Initial quorum denominator should be 6");
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

        // Sort signers and signatures by signer address
        sortSignersAndSignatures(signers, signatures);

        // Verify signatures
        verifySignatures(digest, signers, signatures);

        // Create signature data
        // Note: referenceBlock must be a valid block that exists and is in the past
        // Make sure we're at least at block 1 before subtracting offset
        uint32 currentBlock = uint32(block.number);
        if (!(currentBlock > referenceBlockOffset)) {
            revert MirrorQuorumSyncHandlerTest__BlockNumberTooLowForOffset();
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
            revert MirrorQuorumSyncHandlerTest__ArraysLengthMismatch();
        }

        for (uint256 i = 0; i < signers.length; ++i) {
            address recovered = ECDSA.recover(digest, signatures[i]);
            if (recovered != signers[i]) {
                revert MirrorQuorumSyncHandlerTest__SignatureRecoveryFailed();
            }
        }
    }
}
