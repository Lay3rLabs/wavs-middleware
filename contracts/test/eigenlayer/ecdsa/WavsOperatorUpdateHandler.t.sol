// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {
    ECDSAUpgradeable
} from "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";

import {
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {WavsServiceManager} from "src/eigenlayer/ecdsa/WavsServiceManager.sol";
import {
    WavsOperatorUpdateHandler,
    IWavsOperatorUpdateHandler
} from "src/eigenlayer/ecdsa/handlers/WavsOperatorUpdateHandler.sol";
import {IWavsServiceHandler} from "src/eigenlayer/ecdsa/interfaces/IWavsServiceHandler.sol";
import {MockStakeRegistry} from "test/eigenlayer/ecdsa/mocks/MockStakeRegistry.sol";

/**
 * @title WavsOperatorUpdateHandlerTest
 * @author Lay3rLabs
 * @notice This contract contains tests for the WavsOperatorUpdateHandler contract.
 * @dev This contract is used to test the WavsOperatorUpdateHandler contract.
 */
contract WavsOperatorUpdateHandlerTest is Test {
    // Constants
    uint256 private constant OPERATOR_WEIGHT = 10_000;

    address private deployer;
    address private proxyOwner;

    // Contract references
    MockStakeRegistry private stakeRegistry;
    WavsServiceManager private serviceManager;
    WavsOperatorUpdateHandler private serviceHandler;

    // Basic operator data
    address[] private operators;
    uint256[] private weights;
    uint256[] private privateKeys;

    /// @notice The error for the block number too low for offset.
    error WavsOperatorUpdateHandlerTest__BlockNumberTooLowForOffset();
    /// @notice The error for the arrays length mismatch.
    error WavsOperatorUpdateHandlerTest__ArraysLengthMismatch();
    /// @notice The error for the signature recovery failed.
    error WavsOperatorUpdateHandlerTest__SignatureRecoveryFailed();

    /// @notice The setUp function.
    function setUp() public {
        // Set up deployer addresses
        deployer = address(0x123);
        proxyOwner = address(0x456);

        vm.startPrank(deployer);
        stakeRegistry = new MockStakeRegistry();

        // Deploy the implementation contract
        WavsServiceManager implementation = new WavsServiceManager(
            address(this), // avsDirectory
            address(stakeRegistry),
            address(0x101),
            address(0x102),
            address(0x103)
        );
        vm.stopPrank();

        vm.startPrank(proxyOwner);

        // Encode the initialize function call
        bytes memory data = abi.encodeWithSelector(
            WavsServiceManager.initialize.selector,
            deployer, // initialOwner
            deployer // rewardsInitiator
        );
        // Deploy the proxy and initialize it
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            proxyOwner, // admin
            data // initializer data
        );
        // Cast the proxy to the service manager interface
        serviceManager = WavsServiceManager(address(proxy));

        vm.stopPrank();

        vm.startPrank(deployer);

        serviceHandler = new WavsOperatorUpdateHandler(
            serviceManager, ECDSAStakeRegistry(address(stakeRegistry))
        );

        // Create test info for 5 operators
        privateKeys = new uint256[](5);
        operators = new address[](5);
        weights = new uint256[](5);

        for (uint256 i = 0; i < 5; ++i) {
            privateKeys[i] = i + 1;
            operators[i] = vm.addr(privateKeys[i]);
            weights[i] = OPERATOR_WEIGHT;
        }

        // Set up test operator weights
        stakeRegistry.setOperatorWeight(operators[0], weights[0]);
        stakeRegistry.setOperatorWeight(operators[1], weights[1]);
        stakeRegistry.setOperatorWeight(operators[2], weights[2]);
        stakeRegistry.setOperatorWeight(operators[3], weights[3]);
        stakeRegistry.setOperatorWeight(operators[4], weights[4]);
        stakeRegistry.setTotalWeight(weights[0] + weights[1] + weights[2] + weights[3] + weights[4]);
        stakeRegistry.setTotalOperators(5);

        vm.stopPrank();

        // Roll to block 10 to ensure we have enough blocks for reference blocks
        vm.roll(10);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_initial_state function.
    function test_initial_state() public view {
        /* solhint-enable func-name-mixedcase */
        // Test initial state of the service handler
        assertEq(
            address(serviceHandler.getServiceManager()),
            address(serviceManager),
            "Service manager address should be set"
        );
        assertEq(
            address(serviceHandler.getStakeRegistry()),
            address(stakeRegistry),
            "Stake registry address should be set"
        );
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_invalid_payload function.
    function test_invalid_payload() public {
        /* solhint-enable func-name-mixedcase */
        // Create an envelope with invalid payload
        IWavsServiceHandler.Envelope memory envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(1)), ordering: bytes12(0), payload: abi.encode("Bad payload")
        });

        // Create signature data with 4 operators (more than enough to pass quorum)
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 4, 5);

        // Call handleSignedEnvelope should fail with invalid payload
        vm.expectRevert();
        serviceHandler.handleSignedEnvelope(envelope, signatureData);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_insufficient_quorum function.
    function test_insufficient_quorum() public {
        /* solhint-enable func-name-mixedcase */
        // Create a valid UpdateWithId payload with triggerId = 1
        IWavsOperatorUpdateHandler.OperatorUpdatePayload memory updateData =
            IWavsOperatorUpdateHandler.OperatorUpdatePayload({
                operatorsPerQuorum: new address[][](0), quorumNumbers: new bytes(0)
            });

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

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_failed_update_operators function.
    function test_failed_update_operators() public {
        /* solhint-enable func-name-mixedcase */
        // Create the update data with some operators
        IWavsOperatorUpdateHandler.OperatorUpdatePayload memory updateData =
            IWavsOperatorUpdateHandler.OperatorUpdatePayload({
                operatorsPerQuorum: new address[][](1), quorumNumbers: new bytes(0)
            });

        // Create envelope with the encoded payload
        IWavsServiceHandler.Envelope memory envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(1)), ordering: bytes12(0), payload: abi.encode(updateData)
        });

        // 4/5 can pass this with > 2/3
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 4, 0);

        // Call handleSignedEnvelope should fail with MustUpdateAllOperators
        vm.expectRevert(abi.encodeWithSignature("MustUpdateAllOperators()"));
        serviceHandler.handleSignedEnvelope(envelope, signatureData);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_successful_update_operators function.
    function test_successful_update_operators() public {
        /* solhint-enable func-name-mixedcase */
        // Create the update data
        address[][] memory operatorsPerQuorum = new address[][](1);
        operatorsPerQuorum[0] = operators;
        IWavsOperatorUpdateHandler.OperatorUpdatePayload memory updateData =
            IWavsOperatorUpdateHandler.OperatorUpdatePayload({
                operatorsPerQuorum: operatorsPerQuorum, quorumNumbers: new bytes(0)
            });

        // Create envelope with the encoded payload
        IWavsServiceHandler.Envelope memory envelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(uint160(1)), ordering: bytes12(0), payload: abi.encode(updateData)
        });

        // 4/5 can pass this with > 2/3
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 4, 0);

        // total weight starts at all the weights
        uint256 initialTotalWeight = weights[0] + weights[1] + weights[2] + weights[3] + weights[4];
        assertEq(
            stakeRegistry.totalWeight(),
            initialTotalWeight,
            "Total weight should initialize to the sum of the initial weights"
        );

        // update the operators
        serviceHandler.handleSignedEnvelope(envelope, signatureData);

        // mock stake registry doubles even weights and halves odd weights
        uint256 newTotalWeight =
            weights[0] * 2 + weights[1] / 2 + weights[2] * 2 + weights[3] / 2 + weights[4] * 2;
        assertEq(stakeRegistry.totalWeight(), newTotalWeight, "Total weight should be updated");
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
            revert WavsOperatorUpdateHandlerTest__BlockNumberTooLowForOffset();
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
            revert WavsOperatorUpdateHandlerTest__ArraysLengthMismatch();
        }

        for (uint256 i = 0; i < signers.length; ++i) {
            address recovered = ECDSA.recover(digest, signatures[i]);
            if (recovered != signers[i]) {
                revert WavsOperatorUpdateHandlerTest__SignatureRecoveryFailed();
            }
        }
    }
}
