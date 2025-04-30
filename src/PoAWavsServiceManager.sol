// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {ECDSAUpgradeable} from "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {IWavsServiceManager} from "./interfaces/IWavsServiceManager.sol";
import {IWavsServiceHandler} from "./interfaces/IWavsServiceHandler.sol";

/**
 * @title Proof of Authority WAVS Service Manager
 * @notice Implements WAVS service manager with a simple list of operators rather than EigenLayer staking
 * @dev This contract uses a fixed operator set with equal weights for each operator
 */
contract PoAWavsServiceManager is IWavsServiceManager, OwnableUpgradeable {
    using ECDSAUpgradeable for bytes32;

    // Custom errors
    error ZeroAddress();
    error AlreadyOperator();
    error NotOperator();
    error ThresholdTooHigh();
    error MustRequireSignatures();
    error NotEnoughSigners();
    error SignersNotSorted();
    error SignatureArrayMismatch();
    error NotEnoughValidSignatures();

    // The list of authorized operators
    address[] public operators;

    // Mapping to quickly check if an address is an operator
    mapping(address => bool) public isOperator;

    // The number of operators required to sign (default is 2/3)
    uint256 public requiredSignatures;

    // Weight assigned to each operator (all operators have equal weight)
    uint256 public constant OPERATOR_WEIGHT = 1;

    // Service URI
    string public serviceURI;

    // Events
    event OperatorAdded(address operator);
    event OperatorRemoved(address operator);
    event RequiredSignaturesUpdated(uint256 oldValue, uint256 newValue);

    /**
     * @notice Initialize the contract with an initial set of operators
     * @param _initialOperators The initial list of operators
     * @param _requiredSignatures The number of required signatures (threshold)
     * @param _initialOwner The initial owner of the contract
     */
    function initialize(
        address[] memory _initialOperators,
        uint256 _requiredSignatures,
        address _initialOwner
    ) public initializer {
        __Ownable_init();
        _transferOwnership(_initialOwner);

        // Add initial operators first
        for (uint256 i = 0; i < _initialOperators.length; i++) {
            _addOperator(_initialOperators[i]);
        }

        // Set required signatures after operators are added
        _updateRequiredSignatures(_requiredSignatures);
    }

    /**
     * @notice Add a new operator
     * @param operator The address of the operator to add
     */
    function addOperator(address operator) external onlyOwner {
        _addOperator(operator);
    }

    /**
     * @notice Remove an operator
     * @param operator The address of the operator to remove
     */
    function removeOperator(address operator) external onlyOwner {
        _removeOperator(operator);
    }

    /**
     * @notice Set the required number of signatures
     * @param _requiredSignatures The new threshold
     */
    function setRequiredSignatures(
        uint256 _requiredSignatures
    ) external onlyOwner {
        _updateRequiredSignatures(_requiredSignatures);
    }

    /**
     * @notice Validate a message was signed by a sufficient number of operators
     * @param envelope The envelope containing the data
     * @param signatureData The signature data
     */
    function validate(
        IWavsServiceHandler.Envelope calldata envelope,
        IWavsServiceHandler.SignatureData calldata signatureData
    ) external view override {
        bytes32 message = keccak256(abi.encode(envelope));
        bytes32 ethSignedMessageHash = ECDSAUpgradeable.toEthSignedMessageHash(
            message
        );

        // Verify that we have enough signatures
        if (signatureData.operators.length < requiredSignatures) {
            revert NotEnoughSigners();
        }
        if (signatureData.operators.length != signatureData.signatures.length) {
            revert SignatureArrayMismatch();
        }

        uint256 validSignatures = 0;
        address lastSigner = address(0);

        for (uint256 i = 0; i < signatureData.operators.length; i++) {
            address signer = signatureData.operators[i];

            // Check that signers are in ascending order
            if (signer <= lastSigner) {
                revert SignersNotSorted();
            }
            lastSigner = signer;

            // Verify the signer is an operator
            if (!isOperator[signer]) {
                revert NotOperator();
            }

            // Verify the signature
            bool isValid = _isValidSignature(
                signer,
                ethSignedMessageHash,
                signatureData.signatures[i]
            );
            if (!isValid) {
                revert InvalidSignature();
            }

            validSignatures++;
        }

        if (validSignatures < requiredSignatures) {
            revert NotEnoughValidSignatures();
        }
    }

    /**
     * @notice Get the weight of an operator
     * @param operator The operator address
     * @return The weight of the operator (1 if operator, 0 otherwise)
     */
    function getOperatorWeight(
        address operator
    ) external view override returns (uint256) {
        return isOperator[operator] ? OPERATOR_WEIGHT : 0;
    }

    /**
     * @notice Get the total weight from the last checkpoint
     * @return The total weight (equal to the number of operators)
     */
    function getLastCheckpointTotalWeight()
        external
        view
        override
        returns (uint256)
    {
        return operators.length * OPERATOR_WEIGHT;
    }

    /**
     * @notice Get the threshold weight from the last checkpoint
     * @return The threshold weight (equal to requiredSignatures)
     */
    function getLastCheckpointThresholdWeight()
        external
        view
        override
        returns (uint256)
    {
        return requiredSignatures * OPERATOR_WEIGHT;
    }

    /**
     * @inheritdoc IWavsServiceManager
     */
    function getServiceURI() external view override returns (string memory) {
        return serviceURI;
    }

    /**
     * @inheritdoc IWavsServiceManager
     */
    function setServiceURI(
        string calldata _serviceURI
    ) external override onlyOwner {
        serviceURI = _serviceURI;
        emit ServiceURIUpdated(_serviceURI);
    }

    /**
     * @notice Internal function to add an operator
     * @param operator The operator to add
     */
    function _addOperator(address operator) internal {
        if (operator == address(0)) {
            revert ZeroAddress();
        }
        if (isOperator[operator]) {
            revert AlreadyOperator();
        }

        operators.push(operator);
        isOperator[operator] = true;

        emit OperatorAdded(operator);
    }

    /**
     * @notice Internal function to remove an operator
     * @param operator The operator to remove
     */
    function _removeOperator(address operator) internal {
        if (!isOperator[operator]) {
            revert NotOperator();
        }

        // Find and remove the operator from the array
        for (uint256 i = 0; i < operators.length; i++) {
            if (operators[i] == operator) {
                // Replace with the last element and pop
                operators[i] = operators[operators.length - 1];
                operators.pop();
                break;
            }
        }

        isOperator[operator] = false;

        emit OperatorRemoved(operator);

        // Ensure requiredSignatures doesn't exceed the number of operators
        if (requiredSignatures > operators.length) {
            _updateRequiredSignatures(operators.length);
        }
    }

    /**
     * @notice Update the required number of signatures
     * @param _requiredSignatures The new threshold
     */
    function _updateRequiredSignatures(uint256 _requiredSignatures) internal {
        if (_requiredSignatures == 0) {
            revert MustRequireSignatures();
        }
        if (_requiredSignatures > operators.length) {
            revert ThresholdTooHigh();
        }

        uint256 oldValue = requiredSignatures;
        requiredSignatures = _requiredSignatures;

        emit RequiredSignaturesUpdated(oldValue, _requiredSignatures);
    }

    /**
     * @notice Validate a signature
     * @param signer The signer address
     * @param messageHash The hash of the message
     * @param signature The signature to validate
     * @return True if the signature is valid
     */
    function _isValidSignature(
        address signer,
        bytes32 messageHash,
        bytes memory signature
    ) internal view returns (bool) {
        // Try ECDSA signature
        (
            address recovered,
            ECDSAUpgradeable.RecoverError error
        ) = ECDSAUpgradeable.tryRecover(messageHash, signature);
        if (
            error == ECDSAUpgradeable.RecoverError.NoError &&
            recovered == signer
        ) {
            return true;
        }

        // Try ERC1271 signature verification
        try
            IERC1271Upgradeable(signer).isValidSignature(messageHash, signature)
        returns (bytes4 magicValue) {
            return magicValue == IERC1271Upgradeable.isValidSignature.selector;
        } catch {
            return false;
        }
    }
}
