// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {SimpleServiceManager} from "src/eigenlayer/ecdsa/mocks/SimpleServiceManager.sol";
import {IWavsServiceHandler} from "src/eigenlayer/ecdsa/interfaces/IWavsServiceHandler.sol";
import {IWavsServiceManager} from "src/eigenlayer/ecdsa/interfaces/IWavsServiceManager.sol";

/**
 * @title SimpleServiceManagerTest
 * @author Lay3rLabs
 * @notice This contract contains tests for the SimpleServiceManager contract.
 * @dev This contract is used to test the SimpleServiceManager contract.
 */
contract SimpleServiceManagerTest is Test {
    /// @notice The simple service manager.
    SimpleServiceManager public simpleServiceManager;

    /// @notice The operator 1.
    address public operator1 = address(1);
    /// @notice The operator 2.
    address public operator2 = address(2);

    /// @notice The test envelope.
    IWavsServiceHandler.Envelope public testEnvelope;

    /// @notice The setUp function.
    function setUp() public {
        simpleServiceManager = new SimpleServiceManager();

        // Setup test envelope
        testEnvelope = IWavsServiceHandler.Envelope({
            eventId: bytes20(0x1234567890123456789012345678901234567890),
            ordering: bytes12(0),
            payload: bytes("test payload")
        });
    }

    // ============================================================================
    // Constructor and Basic Setup Tests
    // ============================================================================

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_constructor function.
    function test_constructor() public view {
        /* solhint-enable func-name-mixedcase */
        assertEq(simpleServiceManager.getServiceURI(), "");
        assertEq(simpleServiceManager.getLastCheckpointThresholdWeight(), 0);
        assertEq(simpleServiceManager.getLastCheckpointTotalWeight(), 0);
    }

    // ============================================================================
    // Service URI Tests
    // ============================================================================

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_setServiceURI function.
    function test_setServiceURI() public {
        /* solhint-enable func-name-mixedcase */
        string memory newURI = "https://example.com/service";
        vm.expectEmit(true, true, true, true);
        emit IWavsServiceManager.ServiceURIUpdated(newURI);
        simpleServiceManager.setServiceURI(newURI);
        assertEq(simpleServiceManager.getServiceURI(), newURI);
    }

    // ============================================================================
    // Operator Weight Tests
    // ============================================================================

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_setOperatorWeight function.
    function test_setOperatorWeight() public {
        /* solhint-enable func-name-mixedcase */
        simpleServiceManager.setOperatorWeight(operator1, 100);
        assertEq(simpleServiceManager.getOperatorWeight(operator1), 100);
    }

    // ============================================================================
    // Checkpoint Weight Tests
    // ============================================================================

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_setLastCheckpointThresholdWeight function.
    function test_setLastCheckpointThresholdWeight() public {
        /* solhint-enable func-name-mixedcase */
        uint256 weight = 1000;
        simpleServiceManager.setLastCheckpointThresholdWeight(weight);
        assertEq(simpleServiceManager.getLastCheckpointThresholdWeight(), weight);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_setLastCheckpointTotalWeight function.
    function test_setLastCheckpointTotalWeight() public {
        /* solhint-enable func-name-mixedcase */
        uint256 weight = 2000;
        simpleServiceManager.setLastCheckpointTotalWeight(weight);
        assertEq(simpleServiceManager.getLastCheckpointTotalWeight(), weight);
    }

    // ============================================================================
    // Validate Function Tests
    // ============================================================================

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_validate_success function.
    function test_validate_success() public {
        /* solhint-enable func-name-mixedcase */
        // Setup operators with weights
        simpleServiceManager.setOperatorWeight(operator1, 100);
        simpleServiceManager.setOperatorWeight(operator2, 200);
        simpleServiceManager.setLastCheckpointThresholdWeight(150);

        // Create signature data with sorted operators
        address[] memory signers = new address[](2);
        signers[0] = operator1;
        signers[1] = operator2;

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = bytes("signature1");
        signatures[1] = bytes("signature2");

        IWavsServiceHandler.SignatureData memory signatureData = IWavsServiceHandler.SignatureData({
            signers: signers,
            signatures: signatures,
            referenceBlock: uint32(block.number - 1)
        });

        // Should not revert
        simpleServiceManager.validate(testEnvelope, signatureData);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_validate_emptySigners function.
    function test_validate_emptySigners() public {
        /* solhint-enable func-name-mixedcase */
        address[] memory signers = new address[](0);
        bytes[] memory signatures = new bytes[](0);

        IWavsServiceHandler.SignatureData memory signatureData = IWavsServiceHandler.SignatureData({
            signers: signers,
            signatures: signatures,
            referenceBlock: uint32(block.number - 1)
        });

        vm.expectRevert(IWavsServiceManager.InvalidSignatureLength.selector);
        simpleServiceManager.validate(testEnvelope, signatureData);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_validate_mismatchedLengths function.
    function test_validate_mismatchedLengths() public {
        /* solhint-enable func-name-mixedcase */
        address[] memory signers = new address[](2);
        signers[0] = operator1;
        signers[1] = operator2;

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = bytes("signature1");

        IWavsServiceHandler.SignatureData memory signatureData = IWavsServiceHandler.SignatureData({
            signers: signers,
            signatures: signatures,
            referenceBlock: uint32(block.number - 1)
        });

        vm.expectRevert(IWavsServiceManager.InvalidSignatureLength.selector);
        simpleServiceManager.validate(testEnvelope, signatureData);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_validate_invalidBlock function.
    function test_validate_invalidBlock() public {
        /* solhint-enable func-name-mixedcase */
        address[] memory signers = new address[](1);
        signers[0] = operator1;

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = bytes("signature1");

        IWavsServiceHandler.SignatureData memory signatureData = IWavsServiceHandler.SignatureData({
            signers: signers,
            signatures: signatures,
            referenceBlock: uint32(block.number + 1)
        });

        vm.expectRevert(IWavsServiceManager.InvalidSignatureBlock.selector);
        simpleServiceManager.validate(testEnvelope, signatureData);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_validate_unsortedOperators function.
    function test_validate_unsortedOperators() public {
        /* solhint-enable func-name-mixedcase */
        // Setup operators with weights
        simpleServiceManager.setOperatorWeight(operator2, 200);
        simpleServiceManager.setOperatorWeight(operator1, 100);
        simpleServiceManager.setLastCheckpointThresholdWeight(150);

        // Create signature data with unsorted operators (operator2 > operator1)
        address[] memory signers = new address[](2);
        signers[0] = operator2;
        signers[1] = operator1;

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = bytes("signature1");
        signatures[1] = bytes("signature2");

        IWavsServiceHandler.SignatureData memory signatureData = IWavsServiceHandler.SignatureData({
            signers: signers,
            signatures: signatures,
            referenceBlock: uint32(block.number - 1)
        });

        vm.expectRevert(IWavsServiceManager.InvalidSignatureOrder.selector);
        simpleServiceManager.validate(testEnvelope, signatureData);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_validate_zeroWeight function.
    function test_validate_zeroWeight() public {
        /* solhint-enable func-name-mixedcase */
        // Setup threshold but no operator weights
        simpleServiceManager.setLastCheckpointThresholdWeight(100);

        address[] memory signers = new address[](1);
        signers[0] = operator1;

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = bytes("signature1");

        IWavsServiceHandler.SignatureData memory signatureData = IWavsServiceHandler.SignatureData({
            signers: signers,
            signatures: signatures,
            referenceBlock: uint32(block.number - 1)
        });

        vm.expectRevert(IWavsServiceManager.InsufficientQuorumZero.selector);
        simpleServiceManager.validate(testEnvelope, signatureData);
    }

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_validate_insufficientQuorum function.
    function test_validate_insufficientQuorum() public {
        /* solhint-enable func-name-mixedcase */
        // Setup operators with weights
        simpleServiceManager.setOperatorWeight(operator1, 50);
        simpleServiceManager.setOperatorWeight(operator2, 100);
        simpleServiceManager.setLastCheckpointThresholdWeight(200); // Higher than combined weight
        simpleServiceManager.setLastCheckpointTotalWeight(500);

        address[] memory signers = new address[](2);
        signers[0] = operator1;
        signers[1] = operator2;

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = bytes("signature1");
        signatures[1] = bytes("signature2");

        IWavsServiceHandler.SignatureData memory signatureData = IWavsServiceHandler.SignatureData({
            signers: signers,
            signatures: signatures,
            referenceBlock: uint32(block.number - 1)
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IWavsServiceManager.InsufficientQuorum.selector,
                150, // signedWeight (50 + 100)
                200, // thresholdWeight
                500 // totalWeight
            )
        );
        simpleServiceManager.validate(testEnvelope, signatureData);
    }
}
