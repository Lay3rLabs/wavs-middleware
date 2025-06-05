// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IDelegationManager} from
    "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {ECDSAStakeRegistry, IECDSAStakeRegistryTypes} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {ISignatureUtilsMixinTypes} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtilsMixin.sol";

/**
 * @title Mirror Stake Registry
 * @notice A mock implementation of ECDSAStakeRegistry that doesn't have public methods to update stake or register operators
 * @dev This contract overrides external registration methods to revert and provides an owner-only method to set lookups
 */
contract MirrorStakeRegistry is ECDSAStakeRegistry {
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

    /// @dev Constructor to create MirrorStakeRegistry.
    constructor() ECDSAStakeRegistry(IDelegationManager(address(0))) {

    }

/*
TODO: overrdie this
        /// @notice Initializes the contract with the given parameters.
    /// @param _serviceManager The address of the service manager.
    /// @param thresholdWeight The threshold weight in basis points.
    /// @param quorum The quorum struct containing the details of the quorum thresholds.
    function initialize(
        address _serviceManager,
        uint256 thresholdWeight,
        IECDSAStakeRegistryTypes.Quorum memory quorum
    ) external initializer {
        // TODO
        // __ECDSAStakeRegistry_init(_serviceManager, thresholdWeight, quorum);
    }
*/

    /// @notice Override the registerOperatorWithSignature method to revert
    /// @dev This operation is not supported in the mock implementation
    function registerOperatorWithSignature(
        ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry memory,
        address
    ) external override {
        revert RegistrationNotSupported();
    }

    /// @notice Override the deregisterOperator method to revert
    /// @dev This operation is not supported in the mock implementation
    function deregisterOperator() external override {
        revert DeregistrationNotSupported();
    }

    /// @notice Override the updateOperatorSigningKey method to revert
    /// @dev This operation is not supported in the mock implementation
    function updateOperatorSigningKey(
        address
    ) external override {
        revert SigningKeyUpdateNotSupported();
    }

    /// @notice Override the updateOperators method to revert
    /// @dev This operation is not supported in the mock implementation
    function updateOperators(
        address[] memory
    ) external override {
        revert OperatorUpdateNotSupported();
    }
    
    /// @notice Override the updateOperatorsForQuorum method to revert
    /// @dev This operation is not supported in the mock implementation
    function updateOperatorsForQuorum(
        address[][] memory,
        bytes memory
    ) external override {
        revert QuorumOperatorUpdateNotSupported();
    }

    /// @dev This operation is not supported in the mock implementation
    function updateQuorumConfig(
         IECDSAStakeRegistryTypes.Quorum memory quorum,
         address[] memory operators
    ) external override onlyOwner {
        revert QuorumOperatorUpdateNotSupported();
    }

    /// @dev This operation is not supported in the mock implementation
    function updateMinimumWeight(
         uint256 newMinimumWeight,
         address[] memory operators
    ) external override onlyOwner {
        revert OperatorUpdateNotSupported();
    }

    /// @dev This operation is not supported in the mock implementation
    function updateStakeThreshold(
         uint256 thresholdWeight
    ) external override onlyOwner {
        revert OperatorUpdateNotSupported();
    }

    /// @inheritdoc ECDSAStakeRegistry
    function getOperatorWeight(
        address operator
    ) public view override returns (uint256) {
        // TODO
        return 0;
    }

    /**
     * @notice Sets the operator weight and signing key lookup
     * @dev This is the owner-only entrypoint to set all lookups (weights and operator <-> signing key lookups)
     * @param operator The operator address
     * @param signingKey The signing key to associate with the operator
     * @param weight The weight to assign to the operator
     */
    function setOperatorDetails(
        address operator,
        address signingKey,
        uint256 weight
    ) external onlyOwner {
        // This is a no-op implementation as specified in the requirements
        // It will be expanded in the final implementation
    }

    /**
     * @notice Batch sets multiple operator details at once
     * @dev This is the owner-only entrypoint to set multiple operator lookups at once
     * @param operators Array of operator addresses
     * @param signingKeys Array of signing keys corresponding to the operators
     * @param weights Array of weights corresponding to the operators
     */
    function batchSetOperatorDetails(
        address[] calldata operators,
        address[] calldata signingKeys,
        uint256[] calldata weights
    ) external onlyOwner {
        // This is a no-op implementation as specified in the requirements
        // It will be expanded in the final implementation
    }
}
