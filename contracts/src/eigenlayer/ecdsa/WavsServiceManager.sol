// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {ECDSAServiceManagerBase} from
    "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IECDSAStakeRegistry} from
    "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistryStorage.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import {IRewardsCoordinator} from "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {
    IAllocationManager,
    IAllocationManagerTypes
} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {ISignatureUtilsMixinTypes} from "@eigenlayer/contracts/interfaces/ISignatureUtilsMixin.sol";
import {IStrategy} from "@eigenlayer/contracts/interfaces/IStrategy.sol";
import {ECDSAUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC1271Upgradeable} from
    "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";

import {IWavsServiceManager} from "./interfaces/IWavsServiceManager.sol";
import {IWavsServiceHandler} from "./interfaces/IWavsServiceHandler.sol";

/**
 * @title WavsServiceManager
 * @author Lay3r Labs
 * @notice Primary entrypoint for procuring services from LayerMiddleware.
 * @dev This contract implements the IWavsServiceManager interface
 */
contract WavsServiceManager is ECDSAServiceManagerBase, IWavsServiceManager {
    using ECDSAUpgradeable for bytes32;

    /// @notice The service URI
    string public serviceURI;
    /// @notice The quorum numerator
    uint256 public quorumNumerator;
    /// @notice The quorum denominator
    uint256 public quorumDenominator;

    /**
     * @notice Constructor
     * @param _avsDirectory The address of the AVS directory
     * @param _stakeRegistry The address of the stake registry
     * @param _rewardsCoordinator The address of the rewards coordinator
     * @param _delegationManager The address of the delegation manager
     * @param _allocationManager The address of the allocation manager
     */
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

    /**
     * @notice Initializes the service manager
     * @param _initialOwner The initial owner of the service manager
     * @param _rewardsInitiator The rewards initiator of the service manager
     */
    function initialize(address _initialOwner, address _rewardsInitiator) public initializer {
        __ServiceManagerBase_init(_initialOwner, _rewardsInitiator);
        quorumNumerator = 2;
        quorumDenominator = 3;
    }

    /// NOTE: All OperatorSet functions are `onlyOwner`
    /// although `createOperatorSets` SHOULD be `onlyRegistryCoordinator`
    /// and `addStrategyToOperatorSet`, `removeStrategiesFromOperatorSet` SHOULD be `onlyStakeRegistry`
    /// ---
    /// There is a discrepency between `ServiceManagerBase.sol` and and `ECDSAServiceManagerBase.sol`
    /// and between `StakeRegistry.sol` and `ECDSAStakeRegistry.sol`

    /**
     * @notice Creates new operator sets with the given parameters
     * @param params The parameters for the new operator sets
     */
    function createOperatorSets(
        IAllocationManager.CreateSetParams[] calldata params
    ) external onlyOwner {
        IAllocationManager(allocationManager).createOperatorSets(address(this), params);
    }

    /**
     * @notice Adds strategies to an existing operator set
     * @param operatorSetId The ID of the operator set
     * @param strategies The strategies to add
     */
    function addStrategyToOperatorSet(
        uint32 operatorSetId,
        IStrategy[] calldata strategies
    ) external onlyOwner {
        IAllocationManager(allocationManager).addStrategiesToOperatorSet(
            address(this), operatorSetId, strategies
        );
    }

    /**
     * @notice Removes strategies from an existing operator set
     * @param operatorSetId The ID of the operator set
     * @param strategies The strategies to remove
     */
    function removeStrategiesFromOperatorSet(
        uint32 operatorSetId,
        IStrategy[] calldata strategies
    ) external onlyOwner {
        IAllocationManager(allocationManager).removeStrategiesFromOperatorSet(
            address(this), operatorSetId, strategies
        );
    }

    /**
     * @notice Deregisters an operator from operator sets
     * @param operator The operator to deregister
     * @param operatorSetIds The IDs of the operator sets to deregister from
     */
    function deregisterOperatorFromOperatorSets(
        address operator,
        uint32[] calldata operatorSetIds
    ) external {
        // Implementation logic here
    }

    /**
     * @notice Registers an operator to operator sets
     * @param operator The operator to register
     * @param operatorSetIds The IDs of the operator sets to register to
     * @param operatorSignature The signature of the operator
     */
    function registerOperatorToOperatorSets(
        address operator,
        uint32[] calldata operatorSetIds,
        ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry calldata operatorSignature
    ) external {
        // Implementation logic here
    }

    /// @inheritdoc ECDSAServiceManagerBase
    function createAVSRewardsSubmission(
        IRewardsCoordinator.RewardsSubmission[] calldata /* rewardsSubmissions */
    ) external override {
        // Implementation logic here
    }

    /**
     * @notice Slashes an operator
     * @param params The parameters for the slashing
     */
    function slashOperator(
        IAllocationManagerTypes.SlashingParams calldata params
    ) external {
        // Implementation logic here
    }

    /// @inheritdoc IServiceManager
    function addPendingAdmin(
        address /* admin */
    ) external onlyOwner {
        // _permissionController.addPendingAdmin({account: address(this), admin: admin});
    }

    /// @inheritdoc IServiceManager
    function removePendingAdmin(
        address /* pendingAdmin */
    ) external onlyOwner {
        // _permissionController.removePendingAdmin({account: address(this), admin: pendingAdmin});
    }

    /// @inheritdoc IServiceManager
    function removeAdmin(
        address /* admin */
    ) external onlyOwner {
        // _permissionController.removeAdmin({account: address(this), admin: admin});
    }

    /// @inheritdoc IServiceManager
    function setAppointee(
        address, /* appointee */
        address, /* target */
        bytes4 /* selector */
    ) external onlyOwner {
        // _permissionController.setAppointee({
        //     account: address(this),
        //     appointee: appointee,
        //     target: target,
        //     selector: selector
        // });
    }

    /// @inheritdoc IServiceManager
    function removeAppointee(
        address, /* appointee */
        address, /* target */
        bytes4 /* selector */
    ) external onlyOwner {
        // _permissionController.removeAppointee({
        //     account: address(this),
        //     appointee: appointee,
        //     target: target,
        //     selector: selector
        // });
    }

    /// @inheritdoc ECDSAServiceManagerBase
    function updateAVSMetadataURI(
        string calldata _metadataURI
    ) external override onlyOwner {
        // Use AllocationManager instead of AVSDirectory
        IAllocationManager(allocationManager).updateAVSMetadataURI(address(this), _metadataURI);
    }

    /// @inheritdoc IWavsServiceManager
    function setServiceURI(
        string calldata _serviceURI
    ) external override onlyOwner {
        serviceURI = _serviceURI;
        emit ServiceURIUpdated(_serviceURI);
    }

    /// @inheritdoc IWavsServiceManager
    function getServiceURI() external view override returns (string memory) {
        return serviceURI;
    }

    /// @inheritdoc IWavsServiceManager
    function validate(
        IWavsServiceHandler.Envelope calldata envelope,
        IWavsServiceHandler.SignatureData calldata signatureData
    ) external view {
        // Input validation
        if (
            signatureData.signers.length == 0
                || signatureData.signers.length != signatureData.signatures.length
        ) {
            revert IWavsServiceManager.InvalidSignatureLength();
        }
        if (!(signatureData.referenceBlock < block.number)) {
            revert IWavsServiceManager.InvalidSignatureBlock();
        }

        // Create message hash
        bytes32 message = keccak256(abi.encode(envelope));
        bytes32 ethSignedMessageHash = ECDSAUpgradeable.toEthSignedMessageHash(message);

        // Validate signatures through the stake registry
        bytes4 magicValue = IERC1271Upgradeable.isValidSignature.selector;
        bytes memory signatureDataBytes = abi.encode(
            signatureData.signers, signatureData.signatures, signatureData.referenceBlock
        );

        // Check signature validity
        if (
            magicValue
                != ECDSAStakeRegistry(stakeRegistry).isValidSignature(
                    ethSignedMessageHash, signatureDataBytes
                )
        ) {
            revert IWavsServiceManager.InvalidSignature();
        }

        // Calculate the total weight of the operators that signed
        IECDSAStakeRegistry registry = IECDSAStakeRegistry(stakeRegistry);
        uint256 signedWeight = 0;
        for (uint256 i = 0; i < signatureData.signers.length; ++i) {
            address operator = registry.getOperatorForSigningKeyAtBlock(
                signatureData.signers[i], signatureData.referenceBlock
            );
            signedWeight +=
                registry.getOperatorWeightAtBlock(operator, signatureData.referenceBlock);
        }

        uint256 totalWeight =
            registry.getLastCheckpointTotalWeightAtBlock(signatureData.referenceBlock);

        // Ensure sufficient quorum was reached
        _validateQuorumSigned(signedWeight, totalWeight);
    }

    /**
     * @notice Validates that sufficient quorum has been reached
     * @param signedWeight The total weight of operators who signed
     * @param totalWeight The total weight of all operators
     * @dev Requires at least quorumNumerator/quorumDenominator of the total weight to have signed
     */
    function _validateQuorumSigned(uint256 signedWeight, uint256 totalWeight) internal view {
        // Avoid 0 weight ever passing this check
        if (totalWeight == 0) {
            revert IWavsServiceManager.InsufficientQuorumZero();
        }

        // Calculate threshold weight
        uint256 thresholdWeight = (totalWeight * quorumNumerator) / quorumDenominator;

        // Check if signedWeight >= thresholdWeight
        if (signedWeight < thresholdWeight) {
            revert IWavsServiceManager.InsufficientQuorum(
                signedWeight, thresholdWeight, totalWeight
            );
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
        if (numerator == 0) {
            revert IWavsServiceManager.InvalidQuorumParameters();
        }
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
    function getOperatorWeight(
        address operator
    ) external view returns (uint256) {
        return ECDSAStakeRegistry(stakeRegistry).getLastCheckpointOperatorWeight(operator);
    }

    /// @inheritdoc IWavsServiceManager
    function getLatestOperatorForSigningKey(
        address signingKeyAddress
    ) external view returns (address) {
        return ECDSAStakeRegistry(stakeRegistry).getLatestOperatorForSigningKey(signingKeyAddress);
    }

    /// @inheritdoc IWavsServiceManager
    function getDelegationManager() external view returns (address) {
        return delegationManager;
    }

    /// @inheritdoc IWavsServiceManager
    function getAllocationManager() external view returns (address) {
        return allocationManager;
    }

    /// @inheritdoc IWavsServiceManager
    function getStakeRegistry() external view returns (address) {
        return stakeRegistry;
    }
}
