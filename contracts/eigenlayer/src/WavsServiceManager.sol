// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {ECDSAServiceManagerBase} from
    "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import {ECDSAUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {IWavsServiceManager} from "../../interfaces/IWavsServiceManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {IRewardsCoordinator} from "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IAllocationManager, IAllocationManagerTypes} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {ISignatureUtilsMixinTypes} from "@eigenlayer/contracts/interfaces/ISignatureUtilsMixin.sol";
import {IAVSRegistrar} from "@eigenlayer/contracts/interfaces/IAVSRegistrar.sol";
import {IStrategy} from "@eigenlayer/contracts/interfaces/IStrategy.sol";
import {IWavsServiceHandler} from "../../interfaces/IWavsServiceHandler.sol";

/**
 * @title Primary entrypoint for procuring services from LayerMiddleware.
 * @author Eigen Labs, Inc.
 */
contract WavsServiceManager is ECDSAServiceManagerBase, IWavsServiceManager {
    using ECDSAUpgradeable for bytes32;

    string public serviceURI;
    uint256 public quorumNumerator = 2;
    uint256 public quorumDenominator = 3;

    constructor(
        address _avsDirectory,
        address _stakeRegistry,
        address _rewardsCoordinator,
        address _delegationManager,
        address _allocationManager
    )
        ECDSAServiceManagerBase(
            _avsDirectory,
            _stakeRegistry,
            _rewardsCoordinator,
            _delegationManager,
            _allocationManager
        )
    {}

    function initialize(
        address _initialOwner,
        address _rewardsInitiator
    ) public initializer {
        __ServiceManagerBase_init(_initialOwner, _rewardsInitiator);
    }

    /// NOTE: All OperatorSet functions are `onlyOwner`
    /// although `createOperatorSets` SHOULD be `onlyRegistryCoordinator`
    /// and `addStrategyToOperatorSet`, `removeStrategiesFromOperatorSet` SHOULD be `onlyStakeRegistry`
    /// ---
    /// There is a discrepency between `ServiceManagerBase.sol` and and `ECDSAServiceManagerBase.sol`
    /// and between `StakeRegistry.sol` and `ECDSAStakeRegistry.sol`

    /// @notice Creates new operator sets with the given parameters
    function createOperatorSets(IAllocationManager.CreateSetParams[] memory params) external onlyOwner {
        IAllocationManager(allocationManager).createOperatorSets(address(this), params);
    }

    /// @notice Adds strategies to an existing operator set
    function addStrategyToOperatorSet(uint32 operatorSetId, IStrategy[] memory strategies) external onlyOwner {
        IAllocationManager(allocationManager).addStrategiesToOperatorSet(address(this), operatorSetId, strategies);
    }

    /// @notice Removes strategies from an existing operator set
    function removeStrategiesFromOperatorSet(uint32 operatorSetId, IStrategy[] memory strategies) external onlyOwner {
        IAllocationManager(allocationManager).removeStrategiesFromOperatorSet(address(this), operatorSetId, strategies);
    }

    /// @notice Deregisters an operator from operator sets
    function deregisterOperatorFromOperatorSets(
        address operator,
        uint32[] calldata operatorSetIds
    ) external {
        // Implementation logic here
    }

    /// @notice Registers an operator to operator sets
    function registerOperatorToOperatorSets(
        address operator,
        uint32[] calldata operatorSetIds,
        ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry memory operatorSignature
    ) external {
        // Implementation logic here
    }

    /// @notice Creates AVS rewards submission
    function createAVSRewardsSubmission(IRewardsCoordinator.RewardsSubmission[] calldata rewardsSubmissions) external override {
        // Implementation logic here
    }

    /// @notice Slashes an operator
    function slashOperator(
        IAllocationManagerTypes.SlashingParams memory params
    ) external {
        // Implementation logic here
    }

    /// @inheritdoc IServiceManager
    function addPendingAdmin(
        address admin
    ) external onlyOwner {
        // _permissionController.addPendingAdmin({account: address(this), admin: admin});
    }

    /// @inheritdoc IServiceManager
    function removePendingAdmin(
        address pendingAdmin
    ) external onlyOwner {
        // _permissionController.removePendingAdmin({account: address(this), admin: pendingAdmin});
    }

    /// @inheritdoc IServiceManager
    function removeAdmin(
        address admin
    ) external onlyOwner {
        // _permissionController.removeAdmin({account: address(this), admin: admin});
    }

    /// @inheritdoc IServiceManager
    function setAppointee(address appointee, address target, bytes4 selector) external onlyOwner {
        // _permissionController.setAppointee({
        //     account: address(this),
        //     appointee: appointee,
        //     target: target,
        //     selector: selector
        // });
    }

    /// @inheritdoc IServiceManager
    function removeAppointee(
        address appointee,
        address target,
        bytes4 selector
    ) external onlyOwner {
        // _permissionController.removeAppointee({
        //     account: address(this),
        //     appointee: appointee,
        //     target: target,
        //     selector: selector
        // });
    }

    function updateAVSMetadataURI(
        string memory _metadataURI
    ) external override onlyOwner {
        // Use AllocationManager instead of AVSDirectory
        IAllocationManager(allocationManager).updateAVSMetadataURI(address(this), _metadataURI);
    }

    /// @inheritdoc IWavsServiceManager
    function setServiceURI(string calldata _serviceURI) external override onlyOwner {
        serviceURI = _serviceURI;
        emit ServiceURIUpdated(_serviceURI);
    }

    /// @inheritdoc IWavsServiceManager
    function getServiceURI() external view override returns (string memory) {
        return serviceURI;
    }

    /**
     * @notice Validates an envelope with its associated signatures
     * @param envelope The envelope containing the data to validate
     * @param signatureData The signature data including operators, signatures, and reference block
     * @dev Performs two validations:
     *      1. Signature validity through ECDSAStakeRegistry
     *      2. Quorum check to ensure sufficient stake weight signed (2/3 threshold)
     */
    function validate(
        IWavsServiceHandler.Envelope calldata envelope, 
        IWavsServiceHandler.SignatureData calldata signatureData
    ) external view {
        // Input validation
        if (signatureData.operators.length == 0 || signatureData.operators.length != signatureData.signatures.length) {
            revert IWavsServiceManager.InvalidSignature();
        }
        if (signatureData.referenceBlock >= block.number) {
            revert IWavsServiceManager.InvalidSignature();
        }

        // Create message hash
        bytes32 message = keccak256(abi.encode(envelope));
        bytes32 ethSignedMessageHash = ECDSAUpgradeable.toEthSignedMessageHash(message);
        
        // Validate signatures through the stake registry
        bytes4 magicValue = IERC1271Upgradeable.isValidSignature.selector;
        bytes memory signatureDataBytes = abi.encode(
            signatureData.operators, 
            signatureData.signatures, 
            signatureData.referenceBlock
        );
        
        // Check signature validity
        if (magicValue != ECDSAStakeRegistry(stakeRegistry).isValidSignature(
            ethSignedMessageHash,
            signatureDataBytes
        )) {
            revert IWavsServiceManager.InvalidSignature();
        }

        // Calculate the total weight of the operators that signed
        ECDSAStakeRegistry registry = ECDSAStakeRegistry(stakeRegistry);
        uint256 signedWeight = 0;
        for (uint256 i = 0; i < signatureData.operators.length; i++) {
            signedWeight += registry.getOperatorWeightAtBlock(
                signatureData.operators[i], 
                signatureData.referenceBlock
            );
        }
        
        uint256 totalWeight = registry.getLastCheckpointTotalWeightAtBlock(signatureData.referenceBlock);
        
        // Ensure sufficient quorum was reached
        _validateQuorumSigned(signedWeight, totalWeight);
    }

    /**
     * @notice Validates that sufficient quorum has been reached
     * @param signedWeight The total weight of operators who signed
     * @param totalWeight The total weight of all operators
     * @dev Requires at least 2/3 of the total weight to have signed
     */
    /**
     * @notice Validates that sufficient quorum has been reached
     * @param signedWeight The total weight of operators who signed
     * @param totalWeight The total weight of all operators
     * @dev Requires at least quorumNumerator/quorumDenominator of the total weight to have signed
     */
    function _validateQuorumSigned(
        uint256 signedWeight,
        uint256 totalWeight
    ) internal view {
        // Avoid 0 weight ever passing this check
        if (totalWeight == 0) {
            revert IWavsServiceManager.InsufficientQuorum();
        }
        
        // Check if signedWeight >= (quorumNumerator/quorumDenominator) * totalWeight
        // Multiply both sides by quorumDenominator to avoid floating point:
        // signedWeight * quorumDenominator >= totalWeight * quorumNumerator
        if (signedWeight * quorumDenominator < totalWeight * quorumNumerator) {
            revert IWavsServiceManager.InsufficientQuorum();
        }
    }
    
    /**
     * @notice Sets a new quorum threshold for signature validation
     * @param numerator The numerator of the quorum fraction
     * @param denominator The denominator of the quorum fraction
     * @dev The fraction numerator/denominator represents the minimum portion of stake
     *      required for a valid signature (e.g., 2/3 or 51/100)
     */
    function setQuorumThreshold(uint256 numerator, uint256 denominator) external onlyOwner {
        if (denominator == 0) {
            revert IWavsServiceManager.InvalidQuorumParameters();
        }
        if (numerator > denominator) {
            revert IWavsServiceManager.InvalidQuorumParameters();
        }
        
        quorumNumerator = numerator;
        quorumDenominator = denominator;
        
        emit QuorumThresholdUpdated(numerator, denominator);
    }

    /// @inheritdoc IWavsServiceManager
    function getOperatorWeight(address operator) external view returns (uint256) {
        return ECDSAStakeRegistry(stakeRegistry).getLastCheckpointOperatorWeight(operator);
    }
}
