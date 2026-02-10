// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {
    IDelegationManager
} from "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {
    ECDSAStakeRegistry,
    IECDSAStakeRegistryTypes
} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {
    ISignatureUtilsMixinTypes
} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtilsMixin.sol";
import {
    CheckpointsUpgradeable
} from "@openzeppelin-upgrades/contracts/utils/CheckpointsUpgradeable.sol";

/**
 * @title Mirror Stake Registry
 * @author Lay3r Labs
 * @notice A mock implementation of ECDSAStakeRegistry that doesn't have public methods to update stake or register operators
 * @dev This contract overrides external registration methods to revert and provides an owner-only method to set lookups
 */
contract MirrorStakeRegistry is ECDSAStakeRegistry {
    using CheckpointsUpgradeable for CheckpointsUpgradeable.History;

    /// @notice Error thrown when attempting to register an operator through the public method
    error RegistrationNotSupported();
    /// @notice Error thrown when attempting to deregister an operator through the public method
    error DeregistrationNotSupported();
    /// @notice Error thrown when attempting to update an operator's signing key through the public method
    error SigningKeyUpdateNotSupported();
    /// @notice Error thrown when attempting to update operators through the public method
    error OperatorUpdateNotSupported();
    /// @notice Error thrown when attempting to update operators for quorum through the public method
    error QuorumOperatorUpdateNotSupported();
    /// @notice Error thrown when array lengths don't match in batch operations
    error InvalidArrayLengths();

    /// @notice The constructor for the MirrorStakeRegistry.
    constructor() ECDSAStakeRegistry(IDelegationManager(address(0))) {}

    /**
     * @notice Initializes the contract with the given parameters.
     * @param _serviceManager The address of the service manager.
     * @param thresholdWeight The threshold weight in basis points.
     * @param quorum The quorum struct containing the details of the quorum thresholds.
     */
    function initialize(
        address _serviceManager,
        uint256 thresholdWeight,
        IECDSAStakeRegistryTypes.Quorum calldata quorum
    ) external override initializer {
        // We can't override initialize since it's not virtual in the parent contract
        // But we can still call the internal initialization function
        __ECDSAStakeRegistry_init(_serviceManager, thresholdWeight, quorum);
    }

    /// @inheritdoc ECDSAStakeRegistry
    function registerOperatorWithSignature(
        ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry calldata, /* operatorSignature */
        address /* signingKey */
    ) external pure override {
        revert RegistrationNotSupported();
    }

    /// @inheritdoc ECDSAStakeRegistry
    function deregisterOperator() external pure override {
        revert DeregistrationNotSupported();
    }

    /// @inheritdoc ECDSAStakeRegistry
    function updateOperatorSigningKey(
        address /* newSigningKey */
    ) external pure override {
        revert SigningKeyUpdateNotSupported();
    }

    /// @inheritdoc ECDSAStakeRegistry
    function updateOperators(
        address[] calldata /* operators */
    ) external pure override {
        revert OperatorUpdateNotSupported();
    }

    /// @inheritdoc ECDSAStakeRegistry
    function updateOperatorsForQuorum(
        address[][] calldata, /* operators */
        bytes calldata /* data */
    ) external pure override {
        revert QuorumOperatorUpdateNotSupported();
    }

    /// @inheritdoc ECDSAStakeRegistry
    function updateQuorumConfig(
        IECDSAStakeRegistryTypes.Quorum calldata, /* quorum */
        address[] calldata /* operators */
    ) external pure override {
        revert QuorumOperatorUpdateNotSupported();
    }

    /// @inheritdoc ECDSAStakeRegistry
    function updateMinimumWeight(
        uint256, /* minimumWeight */
        address[] calldata /* operators */
    ) external pure override {
        revert OperatorUpdateNotSupported();
    }

    /// @inheritdoc ECDSAStakeRegistry
    function getOperatorWeight(
        address operator
    ) public view override returns (uint256) {
        return _operatorWeightHistory[operator].latest();
    }

    /**
     * @notice Sets the operator weight and signing key lookup
     * @dev This is the owner-only entrypoint to set all lookups (weights and operator <-> signing key lookups)
     * @param operator The operator address
     * @param signingKeyAddress The signing key to associate with the operator
     * @param weight The weight to assign to the operator
     */
    function setOperatorDetails(
        address operator,
        address signingKeyAddress,
        uint256 weight
    ) external onlyOwner {
        _setOperatorDetails(operator, signingKeyAddress, weight);
    }

    /**
     * @notice Batch sets multiple operator details at once
     * @dev This is the owner-only entrypoint to set multiple operator lookups at once
     * @param operators Array of operator addresses
     * @param signingKeyAddresses Array of signing keys corresponding to the operators
     * @param weights Array of weights corresponding to the operators
     */
    function batchSetOperatorDetails(
        address[] calldata operators,
        address[] calldata signingKeyAddresses,
        uint256[] calldata weights
    ) external onlyOwner {
        // Validate array lengths match
        if (operators.length != signingKeyAddresses.length || operators.length != weights.length) {
            revert InvalidArrayLengths();
        }

        uint256 length = operators.length;
        for (uint256 i = 0; i < length; ++i) {
            _setOperatorDetails(operators[i], signingKeyAddresses[i], weights[i]);
        }
    }

    /**
     * @notice Returns the service manager address
     * @return The address of the service manager
     */
    function serviceManager() external view returns (address) {
        return _serviceManager;
    }

    /**
     * @notice Internal function to set operator details
     * @dev Internal function to set operator details
     * @param operator The operator address
     * @param signingKeyAddress The signing key to associate with the operator
     * @param weight The weight to assign to the operator
     */
    function _setOperatorDetails(
        address operator,
        address signingKeyAddress,
        uint256 weight
    ) internal {
        // Get the current weight of the operator
        uint256 currentWeight = _operatorWeightHistory[operator].latest();

        // Calculate the weight delta
        int256 weightDelta = int256(weight) - int256(currentWeight);

        // Update the operator weight
        _operatorWeightHistory[operator].push(weight);

        // Update the total weight
        (uint256 oldTotalWeight, uint256 newTotalWeight) = _updateTotalWeight(weightDelta);

        // Get the current signing key for the operator
        address currentSigningKey = address(uint160(_operatorSigningKeyHistory[operator].latest()));

        // If the signing key is different, update the mappings
        if (currentSigningKey != signingKeyAddress) {
            // Remove the old signing key mapping if it exists
            if (currentSigningKey != address(0)) {
                // Clear the old signing key to operator mapping in history
                _signingKeyToOperatorHistory[currentSigningKey].push(0); // Set to 0 to indicate no operator
            }

            // Set the new signing key mapping
            _operatorSigningKeyHistory[operator].push(uint256(uint160(signingKeyAddress)));
            _signingKeyToOperatorHistory[signingKeyAddress].push(uint256(uint160(operator)));
        }

        // Mark the operator as registered
        _operatorRegistered[operator] = true;

        // Emit events
        emit OperatorWeightUpdated(operator, currentWeight, weight);
        emit TotalWeightUpdated(oldTotalWeight, newTotalWeight);

        if (currentSigningKey != signingKeyAddress) {
            emit SigningKeyUpdate(operator, block.number, signingKeyAddress, currentSigningKey);
        }
    }
}
