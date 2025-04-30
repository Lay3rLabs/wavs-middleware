// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../src/PoAWavsServiceManager.sol";
import "../src/interfaces/IWavsServiceHandler.sol";

contract PoAWavsServiceManagerTest is Test {
    PoAWavsServiceManager public poaManager;

    address public owner = address(0x123);
    address public operator1;
    address public operator2;
    address public operator3;

    uint256 private operator1Key;
    uint256 private operator2Key;
    uint256 private operator3Key;

    function setUp() public {
        vm.startPrank(owner);

        // Generate keys and derive addresses
        operator1Key = 0x111;
        operator2Key = 0x222;
        operator3Key = 0x333;

        operator1 = vm.addr(operator1Key);
        operator2 = vm.addr(operator2Key);
        operator3 = vm.addr(operator3Key);

        // Create array of initial operators - ensure sorted order
        address[] memory initialOperators = new address[](3);
        initialOperators[0] = operator1;
        initialOperators[1] = operator2;
        initialOperators[2] = operator3;

        // Deploy and initialize the contract
        poaManager = new PoAWavsServiceManager();
        poaManager.initialize(initialOperators, 2, owner); // 2 out of 3 required signatures

        vm.stopPrank();
    }

    function testInitialization() public {
        // Check operators were initialized correctly
        assertTrue(poaManager.isOperator(operator1));
        assertTrue(poaManager.isOperator(operator2));
        assertTrue(poaManager.isOperator(operator3));

        // Check operator weights
        assertEq(poaManager.getOperatorWeight(operator1), 1);
        assertEq(poaManager.getOperatorWeight(operator2), 1);
        assertEq(poaManager.getOperatorWeight(operator3), 1);

        // Check non-operator has 0 weight
        assertEq(poaManager.getOperatorWeight(address(0x999)), 0);

        // Check total weight is 3 (3 operators * 1 weight each)
        assertEq(poaManager.getLastCheckpointTotalWeight(), 3);

        // Check threshold weight is 2 (as we set 2 required signatures)
        assertEq(poaManager.getLastCheckpointThresholdWeight(), 2);
    }

    function testOwnerAddRemoveOperator() public {
        address newOperator = address(0xdef);

        vm.startPrank(owner);

        // Add new operator
        poaManager.addOperator(newOperator);
        assertTrue(poaManager.isOperator(newOperator));
        assertEq(poaManager.getLastCheckpointTotalWeight(), 4);

        // Remove an operator
        poaManager.removeOperator(operator1);
        assertFalse(poaManager.isOperator(operator1));
        assertEq(poaManager.getLastCheckpointTotalWeight(), 3);

        vm.stopPrank();
    }

    function testSetRequiredSignatures() public {
        vm.startPrank(owner);

        // Change required signatures to 3
        poaManager.setRequiredSignatures(3);
        assertEq(poaManager.getLastCheckpointThresholdWeight(), 3);

        // Should revert if trying to set more than available operators
        vm.expectRevert(PoAWavsServiceManager.ThresholdTooHigh.selector);
        poaManager.setRequiredSignatures(4);

        // Should revert if trying to set 0
        vm.expectRevert(PoAWavsServiceManager.MustRequireSignatures.selector);
        poaManager.setRequiredSignatures(0);

        vm.stopPrank();
    }

    function testValidate() public {
        // Create an envelope
        IWavsServiceHandler.Envelope memory envelope;
        envelope.eventId = bytes20(keccak256("testEvent"));
        envelope.payload = abi.encode("test payload");

        // Create the message hash that will be signed
        bytes32 messageHash = keccak256(abi.encode(envelope));
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        // Sign with operator1 and operator2 (make sure addresses are sorted)
        bytes memory signature1 = _signMessage(
            operator1Key,
            ethSignedMessageHash
        );
        bytes memory signature2 = _signMessage(
            operator2Key,
            ethSignedMessageHash
        );

        // Create signature data in sorted order
        address[] memory signers = new address[](2);
        bytes[] memory signatures = new bytes[](2);

        // Ensure we sort by address
        if (operator1 < operator2) {
            signers[0] = operator1;
            signers[1] = operator2;
            signatures[0] = signature1;
            signatures[1] = signature2;
        } else {
            signers[0] = operator2;
            signers[1] = operator1;
            signatures[0] = signature2;
            signatures[1] = signature1;
        }

        IWavsServiceHandler.SignatureData memory signatureData;
        signatureData.operators = signers;
        signatureData.signatures = signatures;
        signatureData.referenceBlock = uint32(block.number - 1);

        // Mock the signer verification process for the test
        vm.mockCall(
            signers[0],
            abi.encodeWithSelector(
                IERC1271Upgradeable.isValidSignature.selector,
                ethSignedMessageHash,
                signatures[0]
            ),
            abi.encode(IERC1271Upgradeable.isValidSignature.selector)
        );

        vm.mockCall(
            signers[1],
            abi.encodeWithSelector(
                IERC1271Upgradeable.isValidSignature.selector,
                ethSignedMessageHash,
                signatures[1]
            ),
            abi.encode(IERC1271Upgradeable.isValidSignature.selector)
        );

        // This should not revert if the signatures are valid
        poaManager.validate(envelope, signatureData);
    }

    function testRejectInvalidSignature() public {
        // Create an envelope
        IWavsServiceHandler.Envelope memory envelope;
        envelope.eventId = bytes20(keccak256("testEvent"));
        envelope.payload = abi.encode("test payload");

        // Create message hash
        bytes32 messageHash = keccak256(abi.encode(envelope));
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        // Create a different message hash (wrong message)
        bytes32 wrongMessageHash = keccak256(abi.encode("wrong message"));
        bytes32 wrongEthSignedMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                wrongMessageHash
            )
        );

        // Sign with operator1 correctly and operator2 incorrectly
        bytes memory signature1 = _signMessage(
            operator1Key,
            ethSignedMessageHash
        );
        bytes memory signature2 = _signMessage(
            operator2Key,
            wrongEthSignedMessageHash
        );

        // Prepare signature data
        address[] memory signers = new address[](2);
        bytes[] memory signatures = new bytes[](2);

        // Ensure proper sorting
        if (operator1 < operator2) {
            signers[0] = operator1;
            signers[1] = operator2;
            signatures[0] = signature1;
            signatures[1] = signature2;
        } else {
            signers[0] = operator2;
            signers[1] = operator1;
            signatures[0] = signature2;
            signatures[1] = signature1;
        }

        IWavsServiceHandler.SignatureData memory signatureData;
        signatureData.operators = signers;
        signatureData.signatures = signatures;
        signatureData.referenceBlock = uint32(block.number - 1);

        // Mock the first signature as valid
        vm.mockCall(
            signers[0],
            abi.encodeWithSelector(
                IERC1271Upgradeable.isValidSignature.selector,
                ethSignedMessageHash,
                signatures[0]
            ),
            abi.encode(IERC1271Upgradeable.isValidSignature.selector)
        );

        // Mock the second signature as invalid (returns 0x00000000)
        vm.mockCall(
            signers[1],
            abi.encodeWithSelector(
                IERC1271Upgradeable.isValidSignature.selector,
                ethSignedMessageHash,
                signatures[1]
            ),
            abi.encode(bytes4(0))
        );

        // Should revert due to invalid signature
        vm.expectRevert(IWavsServiceManager.InvalidSignature.selector);
        poaManager.validate(envelope, signatureData);
    }

    function testServiceURI() public {
        vm.startPrank(owner);

        string memory uri = "https://example.com/service";
        poaManager.setServiceURI(uri);
        assertEq(poaManager.getServiceURI(), uri);

        vm.stopPrank();
    }

    function testErrorsAddingOperator() public {
        vm.startPrank(owner);

        // Should revert if adding a zero address
        vm.expectRevert(PoAWavsServiceManager.ZeroAddress.selector);
        poaManager.addOperator(address(0));

        // Should revert if operator already exists
        vm.expectRevert(PoAWavsServiceManager.AlreadyOperator.selector);
        poaManager.addOperator(operator1);

        vm.stopPrank();
    }

    function testErrorsRemovingOperator() public {
        vm.startPrank(owner);

        // Should revert if operator doesn't exist
        vm.expectRevert(PoAWavsServiceManager.NotOperator.selector);
        poaManager.removeOperator(address(0xdead));

        vm.stopPrank();
    }

    function testSignatureValidationErrors() public {
        // Create an envelope
        IWavsServiceHandler.Envelope memory envelope;
        envelope.eventId = bytes20(keccak256("testEvent"));
        envelope.payload = abi.encode("test payload");

        bytes32 messageHash = keccak256(abi.encode(envelope));
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        // Test for not enough signers
        address[] memory signers = new address[](1);
        signers[0] = operator1;
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signMessage(operator1Key, ethSignedMessageHash);

        IWavsServiceHandler.SignatureData memory signatureData;
        signatureData.operators = signers;
        signatureData.signatures = signatures;
        signatureData.referenceBlock = uint32(block.number - 1);

        vm.expectRevert(PoAWavsServiceManager.NotEnoughSigners.selector);
        poaManager.validate(envelope, signatureData);

        // Test for signature array mismatch
        signers = new address[](2);
        signers[0] = operator1;
        signers[1] = operator2;
        // Keep signatures array length at 1

        signatureData.operators = signers;

        vm.expectRevert(PoAWavsServiceManager.SignatureArrayMismatch.selector);
        poaManager.validate(envelope, signatureData);

        // Test for signers not sorted (only if operator addresses require sorting)
        if (operator2 < operator1) {
            signers = new address[](2);
            signers[0] = operator1; // Higher address first
            signers[1] = operator2; // Lower address second (not sorted)
            signatures = new bytes[](2);
            signatures[0] = _signMessage(operator1Key, ethSignedMessageHash);
            signatures[1] = _signMessage(operator2Key, ethSignedMessageHash);

            signatureData.operators = signers;
            signatureData.signatures = signatures;

            vm.expectRevert(PoAWavsServiceManager.SignersNotSorted.selector);
            poaManager.validate(envelope, signatureData);
        }

        // Test for non-operator
        address nonOperator = address(0xbeef);
        uint256 nonOperatorKey = 0xbeef;

        // Ensure the non-operator address is ordered correctly
        address firstSigner;
        address secondSigner;
        bytes memory firstSignature;
        bytes memory secondSignature;

        if (nonOperator < operator1) {
            firstSigner = nonOperator;
            secondSigner = operator1;
            firstSignature = _signMessage(nonOperatorKey, ethSignedMessageHash);
            secondSignature = _signMessage(operator1Key, ethSignedMessageHash);
        } else {
            firstSigner = operator1;
            secondSigner = nonOperator;
            firstSignature = _signMessage(operator1Key, ethSignedMessageHash);
            secondSignature = _signMessage(
                nonOperatorKey,
                ethSignedMessageHash
            );
        }

        signers = new address[](2);
        signers[0] = firstSigner;
        signers[1] = secondSigner;
        signatures = new bytes[](2);
        signatures[0] = firstSignature;
        signatures[1] = secondSignature;

        signatureData.operators = signers;
        signatureData.signatures = signatures;

        // Mock the operator signature as valid
        vm.mockCall(
            operator1,
            abi.encodeWithSelector(
                IERC1271Upgradeable.isValidSignature.selector,
                ethSignedMessageHash,
                firstSigner == operator1 ? firstSignature : secondSignature
            ),
            abi.encode(IERC1271Upgradeable.isValidSignature.selector)
        );

        vm.expectRevert(PoAWavsServiceManager.NotOperator.selector);
        poaManager.validate(envelope, signatureData);
    }

    // Helper function to sign a message
    function _signMessage(
        uint256 privateKey,
        bytes32 digest
    ) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
