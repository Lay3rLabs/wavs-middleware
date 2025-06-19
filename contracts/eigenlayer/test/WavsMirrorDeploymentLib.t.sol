// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IECDSAStakeRegistryTypes} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ECDSAUpgradeable} from "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";

import {WavsMirrorDeploymentLib} from "../script/utils/WavsMirrorDeploymentLib.sol";
import {UpgradeableProxyLib} from "../script/utils/UpgradeableProxyLib.sol";
import {MirrorStakeRegistry} from "../src/MirrorStakeRegistry.sol";
import {WavsServiceManager} from "../src/WavsServiceManager.sol";
import {IWavsServiceManager} from "../../interfaces/IWavsServiceManager.sol";
import {IWavsServiceHandler} from "../../interfaces/IWavsServiceHandler.sol";

uint256 constant OPERATOR_WEIGHT = 10000;

contract WavsMirrorDeploymentLibTest is Test {
    using UpgradeableProxyLib for address;

    address public deployer;
    address public proxyAdmin;
    WavsMirrorDeploymentLib.DeploymentData public deployment;

    // basic operator data
    address[] public operators;
    address[] public signingKeys;
    uint256[] public weights;
    uint256[] public privateKeys;

    // References to deployed contracts
    MirrorStakeRegistry public stakeRegistry;
    WavsServiceManager public serviceManager;

    error WavsMirrorDeploymentLibTest__BlockNumberTooLowForOffset();
    error WavsMirrorDeploymentLibTest__ArraysLengthMismatch();
    error WavsMirrorDeploymentLibTest__SignatureRecoveryFailed();

    function setUp() public {
        // Set up deployer address
        deployer = address(0x123);
        vm.startPrank(deployer);

        // Deploy proxy admin
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        // Deploy contracts
        deployment = WavsMirrorDeploymentLib.deployContracts(proxyAdmin);
        vm.stopPrank();

        // Create references to deployed contracts
        stakeRegistry = MirrorStakeRegistry(deployment.stakeRegistry);
        serviceManager = WavsServiceManager(deployment.wavsServiceManager);

        // Create test info for 5 operators
        privateKeys = new uint256[](5);
        operators = new address[](5);
        signingKeys = new address[](5);
        weights = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            privateKeys[i] = i + 1;
            operators[i] = vm.addr(privateKeys[i]); // Operators same as signing keys for now
            signingKeys[i] = vm.addr(privateKeys[i]); // Signing keys derived from private keys
            weights[i] = OPERATOR_WEIGHT; // Same weight for all operators
        }

        // Find out the actual owner of the contracts
        address actualOwner = serviceManager.owner();

        // Set up test operator weights as the actual owner
        vm.startPrank(actualOwner);
        stakeRegistry.batchSetOperatorDetails(operators, signingKeys, weights);
        vm.stopPrank();

        // Roll to block 10 to make sure we have plenty of blocks for reference blocks
        // This ensures we're at a high enough block number for the referenceBlockOffset in createSignatureData
        vm.roll(10);
    }

    function test_initial_state() public view {
        // Verify deployment addresses are set correctly
        assertNotEq(deployment.stakeRegistry, address(0), "StakeRegistry address cannot be zero");
        assertNotEq(deployment.wavsServiceManager, address(0), "WavsServiceManager address cannot be zero");
        assertNotEq(proxyAdmin, address(0), "ProxyAdmin address cannot be zero");

        // Verify proxy admin relationships
        address stakeRegistryProxyAdmin = address(UpgradeableProxyLib.getProxyAdmin(deployment.stakeRegistry));
        address serviceManagerProxyAdmin = address(UpgradeableProxyLib.getProxyAdmin(deployment.wavsServiceManager));

        assertEq(stakeRegistryProxyAdmin, proxyAdmin, "StakeRegistry proxy admin should match");
        assertEq(serviceManagerProxyAdmin, proxyAdmin, "WavsServiceManager proxy admin should match");

        // Check implementation addresses
        address stakeRegistryImpl = deployment.stakeRegistry.getImplementation();
        address serviceManagerImpl = deployment.wavsServiceManager.getImplementation();

        assertNotEq(stakeRegistryImpl, address(0), "StakeRegistry implementation cannot be zero");
        assertNotEq(serviceManagerImpl, address(0), "WavsServiceManager implementation cannot be zero");

        // Verify contract relationships
        MirrorStakeRegistry registry = MirrorStakeRegistry(deployment.stakeRegistry);

        assertEq(
            address(registry.serviceManager()),
            deployment.wavsServiceManager,
            "StakeRegistry should reference ServiceManager"
        );

        // Verify that the mock strategy is included in the quorum
        IECDSAStakeRegistryTypes.Quorum memory quorum = registry.quorum();
        assertEq(quorum.strategies.length, 1, "Quorum should have one strategy");
        assertEq(address(quorum.strategies[0].strategy), address(1), "Quorum strategy should be our mock strategy");
    }

    function test_validateQuorumSigned_success() public view {
        // Create the envelope
        IWavsServiceHandler.Envelope memory envelope =
            IWavsServiceHandler.Envelope({eventId: bytes20(uint160(1)), ordering: bytes12(0), payload: "one"});

        // Create signature data with first 4 operators (4/5 >= 2/3 == success)
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 4, 5);

        // Call validate
        serviceManager.validate(envelope, signatureData);
    }

    function test_validateQuorumSigned_insufficient() public {
        // Create the envelope
        IWavsServiceHandler.Envelope memory envelope =
            IWavsServiceHandler.Envelope({eventId: bytes20(uint160(2)), ordering: bytes12(0), payload: "two"});

        // Create signature data with first 3 operators (3/5 < 2/3 == failure)
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 3, 5);

        // Call validate fails
        vm.expectRevert(abi.encodeWithSelector(IWavsServiceManager.InsufficientQuorum.selector, 30000, 33333, 50000));
        serviceManager.validate(envelope, signatureData);
    }

    function test_validateQuorumSigned_exact() public {
        // Change quorum to 3 of 5
        address actualOwner = serviceManager.owner();
        vm.startPrank(actualOwner);
        serviceManager.setQuorumThreshold(3, 5);
        vm.stopPrank();

        // Create the envelope
        IWavsServiceHandler.Envelope memory envelope =
            IWavsServiceHandler.Envelope({eventId: bytes20(uint160(3)), ordering: bytes12(0), payload: "three"});

        // Create signature data with first 4 operators (3/5 >= 3/5 == success)
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 3, 5);

        // Call validate
        serviceManager.validate(envelope, signatureData);
    }

    function test_validateQuorumSigned_explicitSigningKeys() public {
        // Get the actual owner of the contracts
        address actualOwner = serviceManager.owner();

        // Set a new private key and signing key
        privateKeys[0] = 0x13579;
        signingKeys[0] = vm.addr(privateKeys[0]);

        // Update operator to use new signing key
        // Change quorum to 1 of 5, so we just test one signer
        vm.startPrank(actualOwner);
        serviceManager.setQuorumThreshold(1, 5);
        stakeRegistry.setOperatorDetails(operators[0], signingKeys[0], OPERATOR_WEIGHT);
        vm.roll(block.number + 4);
        vm.stopPrank();

        // Add a query to check the signing key registered properly
        address registeredSigningKey = stakeRegistry.getLatestOperatorSigningKey(operators[0]);
        assertEq(registeredSigningKey, signingKeys[0], "Signing key not registered correctly");
        address registeredOperator = stakeRegistry.getLatestOperatorForSigningKey(signingKeys[0]);
        assertEq(registeredOperator, operators[0], "Operator not registered correctly");

        IWavsServiceHandler.Envelope memory envelope =
            IWavsServiceHandler.Envelope({eventId: bytes20(uint160(4)), ordering: bytes12(0), payload: "four"});

        // One operator will match threshold. Ensure lookup by signing key works well.
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 1, 0);

        // Call validate
        serviceManager.validate(envelope, signatureData);
    }

    function test_setQuorumThreshold() public {
        // Change quorum to 3 of 5
        address actualOwner = serviceManager.owner();
        vm.startPrank(actualOwner);
        serviceManager.setQuorumThreshold(51, 100);
        vm.stopPrank();

        assertEq(serviceManager.quorumNumerator(), 51, "Quorum numerator should be updated");
        assertEq(serviceManager.quorumDenominator(), 100, "Quorum denominator should be updated");

        // Create the envelope
        IWavsServiceHandler.Envelope memory envelope =
            IWavsServiceHandler.Envelope({eventId: bytes20(uint160(5)), ordering: bytes12(0), payload: "five"});

        // Create signature data with first 3 operators (3/5 >= 51% == success)
        IWavsServiceHandler.SignatureData memory signatureData = createSignatureData(envelope, 3, 1);
        // Call validate passes
        serviceManager.validate(envelope, signatureData);

        // Create signature data with first 2 operators (2/5 < 51% == failure)
        signatureData = createSignatureData(envelope, 2, 1);
        // Call validate fails
        vm.expectRevert(abi.encodeWithSelector(IWavsServiceManager.InsufficientQuorum.selector, 20000, 25500, 50000));
        serviceManager.validate(envelope, signatureData);
    }

    function test_setQuorumThreshold_only_owner() public {
        // Non-owner should not be able to set quorum threshold
        vm.prank(address(0x999));
        vm.expectRevert("Ownable: caller is not the owner");
        serviceManager.setQuorumThreshold(1, 2);
    }

    function test_setQuorumThreshold_invalid_params() public {
        // Get the actual owner of the contracts
        address actualOwner = serviceManager.owner();

        // Need to call as the owner
        vm.startPrank(actualOwner);

        // 0/5 should fail
        vm.expectRevert(abi.encodeWithSelector(IWavsServiceManager.InvalidQuorumParameters.selector));
        serviceManager.setQuorumThreshold(0, 5);

        // 0/0 should fail
        vm.expectRevert(abi.encodeWithSelector(IWavsServiceManager.InvalidQuorumParameters.selector));
        serviceManager.setQuorumThreshold(0, 0);

        // 6/5 should fail
        vm.expectRevert(abi.encodeWithSelector(IWavsServiceManager.InvalidQuorumParameters.selector));
        serviceManager.setQuorumThreshold(6, 5);

        vm.stopPrank();
    }

    function test_validate_invalid_signature_length() public {
        // Empty operators array
        address[] memory emptySigners = new address[](0);
        bytes[] memory emptySignatures = new bytes[](0);

        vm.expectRevert(abi.encodeWithSelector(IWavsServiceManager.InvalidSignatureLength.selector));
        serviceManager.validate(
            IWavsServiceHandler.Envelope({eventId: bytes20(0), ordering: bytes12(0), payload: ""}),
            IWavsServiceHandler.SignatureData({signers: emptySigners, signatures: emptySignatures, referenceBlock: 1})
        );
    }

    // Helper function to create signature data with a specific number of operators and real signatures
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

        for (uint256 i = 0; i < numOperators; i++) {
            // Generate signer address from private key
            signers[i] = vm.addr(privateKeys[i]);

            // Generate signature using private key
            signatures[i] = generateSignature(privateKeys[i], digest);
        }

        // console.log("Signers");
        // for (uint i = 0; i < signers.length; i++) {
        //    console.log(signers[i]);
        // }

        // Sort signers and signatures by signer address11
        sortSignersAndSignatures(signers, signatures);

        // Verify signatures
        verifySignatures(digest, signers, signatures);

        // Create signature data
        // Note: referenceBlock must be a valid block that exists and is in the past
        // Make sure we're at least at block 1 before subtracting offset
        uint32 currentBlock = uint32(block.number);
        if (currentBlock <= referenceBlockOffset) {
            revert WavsMirrorDeploymentLibTest__BlockNumberTooLowForOffset();
        }

        return IWavsServiceHandler.SignatureData({
            signers: signers,
            signatures: signatures,
            referenceBlock: currentBlock - 1 - referenceBlockOffset
        });
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

    function test_writeAndLoadConfiguration_roundtrip() public {
        // 1. Define a sample InitialConfiguration
        WavsMirrorDeploymentLib.InitialConfiguration memory originalConfig;
        originalConfig.operators = operators; // Use operators from setUp
        originalConfig.signingKeys = signingKeys; // Use signingKeys from setUp
        originalConfig.weights = weights; // Use weights from setUp
        originalConfig.thresholdWeight = 12345;
        originalConfig.quorumNumerator = 2;
        originalConfig.quorumDenominator = 3;

        // 2. Specify a temporary file path
        string memory tempFilePath = "./tempConfig.json";

        // 3. Write the configuration
        WavsMirrorDeploymentLib.writeConfiguration(tempFilePath, originalConfig);

        // Ensure file was created
        assertTrue(vm.exists(tempFilePath), "Config file should exist after writing");

        // 4. Load the configuration
        WavsMirrorDeploymentLib.InitialConfiguration memory loadedConfig =
            WavsMirrorDeploymentLib.loadConfiguration(tempFilePath);

        // 5. Assert that every field matches
        assertEq(loadedConfig.operators.length, originalConfig.operators.length, "Operators length mismatch");
        for (uint256 i = 0; i < originalConfig.operators.length; i++) {
            assertEq(loadedConfig.operators[i], originalConfig.operators[i], "Operator mismatch");
        }

        assertEq(loadedConfig.signingKeys.length, originalConfig.signingKeys.length, "Signing keys length mismatch");
        for (uint256 i = 0; i < originalConfig.signingKeys.length; i++) {
            assertEq(loadedConfig.signingKeys[i], originalConfig.signingKeys[i], "Signing key mismatch");
        }

        assertEq(loadedConfig.weights.length, originalConfig.weights.length, "Weights length mismatch");
        for (uint256 i = 0; i < originalConfig.weights.length; i++) {
            assertEq(loadedConfig.weights[i], originalConfig.weights[i], "Weight mismatch");
        }

        assertEq(loadedConfig.thresholdWeight, originalConfig.thresholdWeight, "Threshold weight mismatch");
        assertEq(loadedConfig.quorumNumerator, originalConfig.quorumNumerator, "Quorum numerator mismatch");
        assertEq(loadedConfig.quorumDenominator, originalConfig.quorumDenominator, "Quorum denominator mismatch");

        // 6. Clean up the temporary file (optional, but good practice for tests)
        // Forge's `vm.removeFile` can be used if available and needed,
        // but often test environments handle temp file cleanup.
        // For now, we'll assume the test runner or environment handles it or it's not critical for this test.
        // If direct cleanup is needed: vm.removeFile(tempFilePath);
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
        if (signers.length != signatures.length) {
            revert WavsMirrorDeploymentLibTest__ArraysLengthMismatch();
        }

        for (uint256 i = 0; i < signers.length; i++) {
            address recovered = ECDSA.recover(digest, signatures[i]);
            if (recovered != signers[i]) {
                revert WavsMirrorDeploymentLibTest__SignatureRecoveryFailed();
            }
        }
    }
}
