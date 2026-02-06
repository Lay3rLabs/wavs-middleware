// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {WavsServiceManager} from "src/eigenlayer/ecdsa/WavsServiceManager.sol";
import {IWavsServiceManager} from "src/eigenlayer/ecdsa/interfaces/IWavsServiceManager.sol";
import {IWavsServiceHandler} from "src/eigenlayer/ecdsa/interfaces/IWavsServiceHandler.sol";
import {MockStakeRegistry} from "test/eigenlayer/ecdsa/mocks/MockStakeRegistry.sol";

uint256 constant OPERATOR_WEIGHT = 100;

/**
 * @title WavsServiceManagerTest
 * @author Lay3rLabs
 * @notice This contract contains tests for the WavsServiceManager contract.
 * @dev This contract is used to test the WavsServiceManager contract.
 */
contract WavsServiceManagerTest is Test {
    /// @notice The service manager.
    WavsServiceManager public serviceManager;
    /// @notice The mock stake registry.
    MockStakeRegistry public mockStakeRegistry;
    /// @notice The owner.
    address public owner = address(0x123);
    /// @notice The proxy owner.
    address public proxyOwner = address(0x456);
    /// @notice The operator 1.
    address public operator1 = address(0x1);
    /// @notice The operator 2.
    address public operator2 = address(0x2);
    /// @notice The operator 3.
    address public operator3 = address(0x3);
    /// @notice The operator 4.
    address public operator4 = address(0x4);
    /// @notice The operator 5.
    address public operator5 = address(0x5);

    /// @notice The setUp function.
    function setUp() public {
        // Set the owner as the caller for all subsequent calls in this test
        vm.startPrank(owner);

        // Deploy mock stake registry
        mockStakeRegistry = new MockStakeRegistry();

        // Deploy the implementation contract
        WavsServiceManager implementation = new WavsServiceManager(
            address(this), // avsDirectory
            address(mockStakeRegistry),
            address(0x101), // rewardsCoordinator
            address(0x102), // delegationManager
            address(0x103) // allocationManager
        );
        vm.stopPrank();

        vm.startPrank(proxyOwner);
        // Encode the initialize function call
        bytes memory data = abi.encodeWithSelector(
            WavsServiceManager.initialize.selector,
            owner, // initialOwner
            owner // rewardsInitiator
        );
        // Deploy the proxy and initialize it
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            proxyOwner, // admin
            data // initializer data
        );
        vm.stopPrank();

        vm.startPrank(owner);
        // Cast the proxy to the service manager interface
        serviceManager = WavsServiceManager(address(proxy));

        // Set up test operator weights
        mockStakeRegistry.setOperatorWeight(operator1, OPERATOR_WEIGHT);
        mockStakeRegistry.setOperatorWeight(operator2, OPERATOR_WEIGHT);
        mockStakeRegistry.setOperatorWeight(operator3, OPERATOR_WEIGHT);
        mockStakeRegistry.setOperatorWeight(operator4, OPERATOR_WEIGHT);
        mockStakeRegistry.setOperatorWeight(operator5, OPERATOR_WEIGHT);
        mockStakeRegistry.setTotalWeight(5 * OPERATOR_WEIGHT);

        vm.stopPrank();
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_initial_state function.
    function test_initial_state() public view {
        /* solhint-enable func-name-mixedcase */
        // Test initial state
        assertEq(serviceManager.quorumNumerator(), 2, "Initial quorum numerator should be 2");
        assertEq(serviceManager.quorumDenominator(), 3, "Initial quorum denominator should be 3");

        address signer = mockStakeRegistry.getLatestOperatorSigningKey(operator1);
        assertEq(signer, operator1, "Initial signer should match operator");
        signer = mockStakeRegistry.getOperatorSigningKeyAtBlock(operator1, block.number - 1);
        assertEq(signer, operator1, "At block query should match operator");
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_validateQuorumSigned_success function.
    function test_validateQuorumSigned_success() public view {
        /* solhint-enable func-name-mixedcase */
        // 2/3 of 500 is 333, so 400 should pass
        serviceManager.validate(
            IWavsServiceHandler.Envelope({eventId: bytes20(0), ordering: bytes12(0), payload: ""}),
            createSignatureData(4, 0)
        );

        // Test should not revert
        assertTrue(true, "Validation should pass with sufficient quorum");
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_validateQuorumSigned_insufficient function.
    function test_validateQuorumSigned_insufficient() public {
        /* solhint-enable func-name-mixedcase */
        // 2/3 of 500 is 333, so 300 should fail
        vm.expectRevert(
            abi.encodeWithSelector(IWavsServiceManager.InsufficientQuorum.selector, 300, 333, 500)
        );
        serviceManager.validate(
            IWavsServiceHandler.Envelope({eventId: bytes20(0), ordering: bytes12(0), payload: ""}),
            createSignatureData(3, 0)
        );
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_validateQuorumSigned_exact function.
    function test_validateQuorumSigned_exact() public {
        /* solhint-enable func-name-mixedcase */
        // Change quorum to 3 of 5
        vm.startPrank(owner);
        serviceManager.setQuorumThreshold(3, 5);
        vm.stopPrank();

        // exact is 3 operators
        serviceManager.validate(
            IWavsServiceHandler.Envelope({eventId: bytes20(0), ordering: bytes12(0), payload: ""}),
            createSignatureData(3, 0)
        );

        // Test should not revert
        assertTrue(true, "Validation should pass with exact quorum");
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_validateQuorumSigned_explicitSigningKeys function.
    function test_validateQuorumSigned_explicitSigningKeys() public {
        /* solhint-enable func-name-mixedcase */
        address signer1 = address(0x13579);

        vm.startPrank(owner);
        // Change quorum to 1 of 5, so we just test one signer
        serviceManager.setQuorumThreshold(1, 5);
        // Set the signing key to something else
        mockStakeRegistry.setOperatorSigner(operator1, signer1);
        vm.stopPrank();

        // Create signature data with signer not operator
        address[] memory signers = new address[](1);
        bytes[] memory signatures = new bytes[](1);
        signers[0] = signer1; // Operators registered 0x1 to 0x5
        signatures[0] = ""; // Empty signature since we're mocking the validation
        IWavsServiceHandler.SignatureData memory signatureData = IWavsServiceHandler.SignatureData({
            signers: signers, signatures: signatures, referenceBlock: uint32(block.number) - 1
        });

        serviceManager.validate(
            IWavsServiceHandler.Envelope({eventId: bytes20(0), ordering: bytes12(0), payload: ""}),
            signatureData
        );

        // Test should not revert
        assertTrue(true, "Validation should pass when signer is set");
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_validateQuorumSigned_zero_total_weight function.
    function test_validateQuorumSigned_zero_total_weight() public {
        /* solhint-enable func-name-mixedcase */
        // Set total weight to 0, which should always fail
        mockStakeRegistry.setTotalWeight(0);

        vm.expectRevert(abi.encodeWithSelector(IWavsServiceManager.InsufficientQuorumZero.selector));
        serviceManager.validate(
            IWavsServiceHandler.Envelope({eventId: bytes20(0), ordering: bytes12(0), payload: ""}),
            createSignatureData(5, 0)
        );
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_setQuorumThreshold function.
    function test_setQuorumThreshold() public {
        /* solhint-enable func-name-mixedcase */
        // Change quorum to 51%
        vm.startPrank(owner);
        serviceManager.setQuorumThreshold(51, 100);
        vm.stopPrank();

        assertEq(serviceManager.quorumNumerator(), 51, "Quorum numerator should be updated");
        assertEq(serviceManager.quorumDenominator(), 100, "Quorum denominator should be updated");

        // 300/500 (60%) should pass
        serviceManager.validate(
            IWavsServiceHandler.Envelope({eventId: bytes20(0), ordering: bytes12(0), payload: ""}),
            createSignatureData(3, 0)
        );

        // Now 200/500 (40%) should fail (needs 255)
        vm.expectRevert(
            abi.encodeWithSelector(IWavsServiceManager.InsufficientQuorum.selector, 200, 255, 500)
        );
        serviceManager.validate(
            IWavsServiceHandler.Envelope({eventId: bytes20(0), ordering: bytes12(0), payload: ""}),
            createSignatureData(2, 0)
        );
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_setQuorumThreshold_only_owner function.
    function test_setQuorumThreshold_only_owner() public {
        /* solhint-enable func-name-mixedcase */
        // Non-owner should not be able to set quorum threshold
        vm.prank(address(0x999));
        vm.expectRevert("Ownable: caller is not the owner");
        serviceManager.setQuorumThreshold(1, 2);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_setQuorumThreshold_invalid_params function.
    function test_setQuorumThreshold_invalid_params() public {
        /* solhint-enable func-name-mixedcase */
        // numerator = 0
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IWavsServiceManager.InvalidQuorumParameters.selector)
        );
        serviceManager.setQuorumThreshold(0, 2);

        // denominator = 0
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IWavsServiceManager.InvalidQuorumParameters.selector)
        );
        serviceManager.setQuorumThreshold(1, 0);

        // numerator > denominator
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IWavsServiceManager.InvalidQuorumParameters.selector)
        );
        serviceManager.setQuorumThreshold(3, 2);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_validate_invalid_signature_length function.
    function test_validate_invalid_signature_length() public {
        /* solhint-enable func-name-mixedcase */
        // Empty operators array
        address[] memory emptySigners = new address[](0);
        bytes[] memory emptySignatures = new bytes[](0);

        vm.expectRevert(abi.encodeWithSelector(IWavsServiceManager.InvalidSignatureLength.selector));
        serviceManager.validate(
            IWavsServiceHandler.Envelope({eventId: bytes20(0), ordering: bytes12(0), payload: ""}),
            IWavsServiceHandler.SignatureData({
                signers: emptySigners, signatures: emptySignatures, referenceBlock: 1
            })
        );
    }

    /**
     * @notice The create signature data function.
     * @param numOperators The number of operators.
     * @param referenceBlockOffset The reference block offset.
     * @return The signature data.
     */
    function createSignatureData(
        uint256 numOperators,
        uint32 referenceBlockOffset
    ) internal view returns (IWavsServiceHandler.SignatureData memory) {
        address[] memory signers = new address[](numOperators);
        bytes[] memory signatures = new bytes[](numOperators);

        for (uint256 i = 0; i < numOperators; ++i) {
            signers[i] = address(uint160(i + 1)); // Operators registered 0x1 to 0x5
            signatures[i] = ""; // Empty signature since we're mocking the validation
        }

        return IWavsServiceHandler.SignatureData({
            signers: signers,
            signatures: signatures,
            referenceBlock: uint32(block.number) - 1 - referenceBlockOffset
        });
    }
}
