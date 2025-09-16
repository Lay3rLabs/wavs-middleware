// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {
    IBLSApkRegistry,
    IBLSApkRegistryTypes
} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {IIndexRegistry} from "@eigenlayer-middleware/src/interfaces/IIndexRegistry.sol";
import {ISocketRegistry} from "@eigenlayer-middleware/src/interfaces/ISocketRegistry.sol";
import {IPauserRegistry} from "eigenlayer-contracts/src/contracts/interfaces/IPauserRegistry.sol";
import {
    IStakeRegistry,
    IStakeRegistryTypes
} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {BitmapUtils} from "@eigenlayer-middleware/src/libraries/BitmapUtils.sol";

import {SlashingRegistryCoordinator} from
    "@eigenlayer-middleware/src/SlashingRegistryCoordinator.sol";
import {IAllocationManager} from
    "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";

import {IMirrorStakeRegistry} from "../interfaces/IMirrorStakeRegistry.sol";
import {IMirrorBLSApkRegistry} from "../interfaces/IMirrorBLSApkRegistry.sol";
import {IMirrorSlashingRegistryCoordinator} from
    "../interfaces/IMirrorSlashingRegistryCoordinator.sol";

/**
 * @title MirrorSlashingRegistryCoordinator
 * @author Lay3rLabs
 * @notice This contract implements the MirrorSlashingRegistryCoordinator contract.
 * @dev This contract is used to coordinate the slashing registry for a mirror.
 */
contract MirrorSlashingRegistryCoordinator is
    SlashingRegistryCoordinator,
    IMirrorSlashingRegistryCoordinator
{
    using BitmapUtils for *;

    /**
     * @notice The constructor for the MirrorSlashingRegistryCoordinator contract.
     * @param _stakeRegistry The stake registry.
     * @param _blsApkRegistry The BLS APK registry.
     * @param _indexRegistry The index registry.
     * @param _socketRegistry The socket registry.
     * @param _allocationManager The allocation manager.
     * @param _pauserRegistry The pauser registry.
     * @param _version The version.
     */
    constructor(
        IStakeRegistry _stakeRegistry,
        IBLSApkRegistry _blsApkRegistry,
        IIndexRegistry _indexRegistry,
        ISocketRegistry _socketRegistry,
        IAllocationManager _allocationManager,
        IPauserRegistry _pauserRegistry,
        string memory _version
    )
        SlashingRegistryCoordinator(
            _stakeRegistry,
            _blsApkRegistry,
            _indexRegistry,
            _socketRegistry,
            _allocationManager,
            _pauserRegistry,
            _version
        )
    {}

    /* solhint-disable gas-calldata-parameters */
    /// @inheritdoc SlashingRegistryCoordinator
    function createTotalDelegatedStakeQuorum(
        OperatorSetParam memory operatorSetParams,
        uint96 minimumStake,
        IStakeRegistryTypes.StrategyParams[] memory strategyParams
    ) external override onlyOwner {
        _createQuorumForMirror(
            operatorSetParams,
            minimumStake,
            strategyParams,
            IStakeRegistryTypes.StakeType.TOTAL_DELEGATED,
            0
        );
    }

    /// @inheritdoc SlashingRegistryCoordinator
    function createSlashableStakeQuorum(
        OperatorSetParam memory operatorSetParams,
        uint96 minimumStake,
        IStakeRegistryTypes.StrategyParams[] memory strategyParams,
        uint32 lookAheadPeriod
    ) external override onlyOwner {
        _createQuorumForMirror(
            operatorSetParams,
            minimumStake,
            strategyParams,
            IStakeRegistryTypes.StakeType.TOTAL_SLASHABLE,
            lookAheadPeriod
        );
    }

    /// @inheritdoc IMirrorSlashingRegistryCoordinator
    function registerOperatorForMirror(
        address operator,
        address avs,
        uint32[] memory operatorSetIds,
        uint96 currentStake,
        bytes calldata data
    ) external onlyOwner onlyWhenNotPaused(PAUSED_REGISTER_OPERATOR) {
        require(supportsAVS(avs), InvalidAVS());
        bytes memory quorumNumbers = _getQuorumNumbers(operatorSetIds);

        (
            RegistrationType registrationType,
            string memory socket,
            IBLSApkRegistryTypes.PubkeyRegistrationParams memory params
        ) = abi.decode(
            data, (RegistrationType, string, IBLSApkRegistryTypes.PubkeyRegistrationParams)
        );

        /**
         * If the operator has NEVER registered a pubkey before, use `params` to register
         * their pubkey in blsApkRegistry
         *
         * If the operator HAS registered a pubkey, `params` is ignored and the pubkey hash
         * (operatorId) is fetched instead
         */
        bytes32 operatorId = IMirrorBLSApkRegistry(address(blsApkRegistry))
            .getOrRegisterOperatorIdForMirror(operator, params);

        if (registrationType == RegistrationType.NORMAL) {
            uint32[] memory numOperatorsPerQuorum = _registerOperatorForMirror({
                operator: operator,
                operatorId: operatorId,
                quorumNumbers: quorumNumbers,
                socket: socket,
                checkMaxOperatorCount: true,
                currentStake: currentStake
            }).numOperatorsPerQuorum;

            // For each quorum, validate that the new operator count does not exceed the maximum
            // (If it does, an operator needs to be replaced -- see `registerOperatorWithChurn`)
            for (uint256 i = 0; i < quorumNumbers.length; ++i) {
                uint8 quorumNumber = uint8(quorumNumbers[i]);

                require(
                    !(numOperatorsPerQuorum[i] > _quorumParams[quorumNumber].maxOperatorCount),
                    MaxOperatorCountReached()
                );
            }
        } else if (registrationType == RegistrationType.CHURN) {
            // Decode registration data from bytes
            (
                ,
                ,
                ,
                OperatorKickParam[] memory operatorKickParams,
                SignatureWithSaltAndExpiry memory churnApproverSignature
            ) = abi.decode(
                data,
                (
                    RegistrationType,
                    string,
                    IBLSApkRegistryTypes.PubkeyRegistrationParams,
                    OperatorKickParam[],
                    SignatureWithSaltAndExpiry
                )
            );
            _registerOperatorWithChurnForMirror({
                operator: operator,
                operatorId: operatorId,
                quorumNumbers: quorumNumbers,
                socket: socket,
                operatorKickParams: operatorKickParams,
                churnApproverSignature: churnApproverSignature,
                currentStake: currentStake
            });
        } else {
            revert InvalidRegistrationType();
        }
    }

    /// @inheritdoc IMirrorSlashingRegistryCoordinator
    function updateOperatorsForMirror(
        uint96[] memory stakeWeights,
        address[] memory operators
    ) external onlyWhenNotPaused(PAUSED_UPDATE_OPERATOR) {
        for (uint256 i = 0; i < operators.length; ++i) {
            // create single-element arrays for the operator and operatorId
            address[] memory singleOperator = new address[](1);
            singleOperator[0] = operators[i];
            bytes32[] memory singleOperatorId = new bytes32[](1);
            singleOperatorId[0] = _operatorInfo[operators[i]].operatorId;

            uint192 currentBitmap = _currentOperatorBitmap(singleOperatorId[0]);
            bytes memory quorumNumbers = currentBitmap.bitmapToBytesArray();
            for (uint256 j = 0; j < quorumNumbers.length; ++j) {
                // update the operator's stake for each quorum
                _updateOperatorsStakesForMirror(
                    stakeWeights, singleOperator, singleOperatorId, uint8(quorumNumbers[j])
                );
            }
        }
    }

    /// @inheritdoc IMirrorSlashingRegistryCoordinator
    function updateOperatorsForQuorumForMirror(
        address[][] memory operatorsPerQuorum,
        uint96[][] memory stakeWeights,
        bytes calldata quorumNumbers
    ) external onlyWhenNotPaused(PAUSED_UPDATE_OPERATOR) {
        // Input validation
        // - all quorums should exist (checked against `quorumCount` in orderedBytesArrayToBitmap)
        // - there should be no duplicates in `quorumNumbers`
        // - there should be one list of operators per quorum
        BitmapUtils.orderedBytesArrayToBitmap(quorumNumbers, quorumCount);
        require(operatorsPerQuorum.length == quorumNumbers.length, InputLengthMismatch());

        // For each quorum, update ALL registered operators
        for (uint256 i = 0; i < quorumNumbers.length; ++i) {
            uint8 quorumNumber = uint8(quorumNumbers[i]);

            // Ensure we've passed in the correct number of operators for this quorum
            address[] memory currQuorumOperators = operatorsPerQuorum[i];
            require(
                currQuorumOperators.length == indexRegistry.totalOperatorsForQuorum(quorumNumber),
                QuorumOperatorCountMismatch()
            );

            bytes32[] memory operatorIds = new bytes32[](currQuorumOperators.length);
            address prevOperatorAddress = address(0);
            // For each operator:
            // - check that they are registered for this quorum
            // - check that their address is strictly greater than the last operator
            // ... then, update their stakes
            for (uint256 j = 0; j < currQuorumOperators.length; ++j) {
                address operator = currQuorumOperators[j];

                operatorIds[j] = _operatorInfo[operator].operatorId;
                {
                    uint192 currentBitmap = _currentOperatorBitmap(operatorIds[j]);
                    // Check that the operator is registered
                    require(
                        BitmapUtils.isSet(currentBitmap, quorumNumber), NotRegisteredForQuorum()
                    );
                    // Prevent duplicate operators
                    require(operator > prevOperatorAddress, NotSorted());
                }

                prevOperatorAddress = operator;
            }

            _updateOperatorsStakesForMirror(
                stakeWeights[i], currQuorumOperators, operatorIds, quorumNumber
            );

            // Update timestamp that all operators in quorum have been updated all at once
            quorumUpdateBlockNumber[quorumNumber] = block.number;
            emit QuorumBlockNumberUpdated(quorumNumber, block.number);
        }
    }

    /**
     * @notice The function to register an operator for a mirror.
     * @param operator The operator.
     * @param operatorId The ID of the operator.
     * @param quorumNumbers The quorum numbers.
     * @param socket The socket.
     * @param checkMaxOperatorCount The flag to check the maximum operator count.
     * @param currentStake The current stake.
     * @return results The register results.
     */
    function _registerOperatorForMirror(
        address operator,
        bytes32 operatorId,
        bytes memory quorumNumbers,
        string memory socket,
        bool checkMaxOperatorCount,
        uint96 currentStake
    ) internal returns (RegisterResults memory results) {
        /**
         * Get bitmap of quorums to register for and operator's current bitmap. Validate that:
         * - we're trying to register for at least 1 quorum
         * - the quorums we're registering for exist (checked against `quorumCount` in orderedBytesArrayToBitmap)
         * - the operator is not currently registered for any quorums we're registering for
         * Then, calculate the operator's new bitmap after registration
         */
        uint192 quorumsToAdd =
            uint192(BitmapUtils.orderedBytesArrayToBitmap(quorumNumbers, quorumCount));
        uint192 currentBitmap = _currentOperatorBitmap(operatorId);

        // call hook to allow for any pre-register logic
        _beforeRegisterOperator(operator, operatorId, quorumNumbers, currentBitmap);

        require(!quorumsToAdd.isEmpty(), BitmapEmpty());
        require(quorumsToAdd.noBitsInCommon(currentBitmap), AlreadyRegisteredForQuorums());
        uint192 newBitmap = uint192(currentBitmap.plus(quorumsToAdd));

        // Check that the operator can reregister if ejected
        require(
            lastEjectionTimestamp[operator] + ejectionCooldown < block.timestamp,
            CannotReregisterYet()
        );

        /**
         * Update operator's bitmap, socket, and status. Only update operatorInfo if needed:
         * if we're `REGISTERED`, the operatorId and status are already correct.
         */
        _updateOperatorBitmap({operatorId: operatorId, newBitmap: newBitmap});

        _setOperatorSocket(operatorId, socket);

        // If the operator wasn't registered for any quorums, update their status
        // and register them with this AVS in EigenLayer core (DelegationManager)
        if (_operatorInfo[operator].status != OperatorStatus.REGISTERED) {
            _operatorInfo[operator] = OperatorInfo(operatorId, OperatorStatus.REGISTERED);
            emit OperatorRegistered(operator, operatorId);
        }

        // Register the operator with the BLSApkRegistry, StakeRegistry, and IndexRegistry
        blsApkRegistry.registerOperator(operator, quorumNumbers);
        (results.operatorStakes, results.totalStakes) = IMirrorStakeRegistry(address(stakeRegistry))
            .registerOperatorForMirror(operatorId, quorumNumbers, currentStake);
        results.numOperatorsPerQuorum = indexRegistry.registerOperator(operatorId, quorumNumbers);

        if (checkMaxOperatorCount) {
            for (uint256 i = 0; i < quorumNumbers.length; ++i) {
                OperatorSetParam memory operatorSetParams = _quorumParams[uint8(quorumNumbers[i])];
                require(
                    !(results.numOperatorsPerQuorum[i] > operatorSetParams.maxOperatorCount),
                    MaxOperatorCountReached()
                );
            }
        }

        // call hook to allow for any post-register logic
        _afterRegisterOperator(operator, operatorId, quorumNumbers, newBitmap);

        return results;
    }

    /**
     * @notice The function to register an operator with churn for a mirror.
     * @param operator The operator.
     * @param operatorId The ID of the operator.
     * @param quorumNumbers The quorum numbers.
     * @param socket The socket.
     * @param operatorKickParams The operator kick parameters.
     * @param churnApproverSignature The churn approver signature.
     * @param currentStake The current stake.
     */
    function _registerOperatorWithChurnForMirror(
        address operator,
        bytes32 operatorId,
        bytes memory quorumNumbers,
        string memory socket,
        OperatorKickParam[] memory operatorKickParams,
        SignatureWithSaltAndExpiry memory churnApproverSignature,
        uint96 currentStake
    ) internal {
        require(operatorKickParams.length == quorumNumbers.length, InputLengthMismatch());

        // Verify the churn approver's signature for the registering operator and kick params
        _verifyChurnApproverSignature({
            registeringOperator: operator,
            registeringOperatorId: operatorId,
            operatorKickParams: operatorKickParams,
            churnApproverSignature: churnApproverSignature
        });

        // Register the operator in each of the registry contracts and update the operator's
        // quorum bitmap and registration status
        RegisterResults memory results = _registerOperatorForMirror({
            operator: operator,
            operatorId: operatorId,
            quorumNumbers: quorumNumbers,
            socket: socket,
            checkMaxOperatorCount: false,
            currentStake: currentStake
        });

        // Check that each quorum's operator count is below the configured maximum. If the max
        // is exceeded, use `operatorKickParams` to deregister an existing operator to make space
        for (uint256 i = 0; i < quorumNumbers.length; ++i) {
            OperatorSetParam memory operatorSetParams = _quorumParams[uint8(quorumNumbers[i])];

            /**
             * If the new operator count for any quorum exceeds the maximum, validate
             * that churn can be performed, then deregister the specified operator
             */
            if (results.numOperatorsPerQuorum[i] > operatorSetParams.maxOperatorCount) {
                _validateChurn({
                    quorumNumber: uint8(quorumNumbers[i]),
                    totalQuorumStake: results.totalStakes[i],
                    newOperator: operator,
                    newOperatorStake: results.operatorStakes[i],
                    kickParams: operatorKickParams[i],
                    setParams: operatorSetParams
                });

                bytes memory singleQuorumNumber = new bytes(1);
                singleQuorumNumber[0] = quorumNumbers[i];
                _kickOperator(operatorKickParams[i].operator, singleQuorumNumber);
            }
        }
    }

    /**
     * @notice The function to create a quorum for a mirror.
     * @param operatorSetParams The operator set parameters.
     * @param minimumStake The minimum stake.
     * @param strategyParams The strategy parameters.
     * @param stakeType The stake type.
     * @param lookAheadPeriod The look ahead period.
     */
    function _createQuorumForMirror(
        OperatorSetParam memory operatorSetParams,
        uint96 minimumStake,
        IStakeRegistryTypes.StrategyParams[] memory strategyParams,
        IStakeRegistryTypes.StakeType stakeType,
        uint32 lookAheadPeriod
    ) internal {
        // The previous quorum count is the new quorum's number,
        // this is because quorum numbers begin from index 0.
        uint8 quorumNumber = quorumCount;

        // Hook to allow for any pre-create quorum logic
        _beforeCreateQuorum(quorumNumber);

        // Increment the total quorum count. Fails if we're already at the max
        require(quorumNumber < MAX_QUORUM_COUNT, MaxQuorumsReached());
        ++quorumCount;

        // Initialize the quorum here and in each registry
        _setOperatorSetParams(quorumNumber, operatorSetParams);

        // Initialize stake registry based on stake type
        if (stakeType == IStakeRegistryTypes.StakeType.TOTAL_DELEGATED) {
            stakeRegistry.initializeDelegatedStakeQuorum(quorumNumber, minimumStake, strategyParams);
        } else if (stakeType == IStakeRegistryTypes.StakeType.TOTAL_SLASHABLE) {
            stakeRegistry.initializeSlashableStakeQuorum(
                quorumNumber, minimumStake, lookAheadPeriod, strategyParams
            );
        }

        indexRegistry.initializeQuorum(quorumNumber);
        blsApkRegistry.initializeQuorum(quorumNumber);

        emit QuorumCreated({
            quorumNumber: quorumNumber,
            operatorSetParams: operatorSetParams,
            minimumStake: minimumStake,
            strategyParams: strategyParams,
            stakeType: stakeType,
            lookAheadPeriod: lookAheadPeriod
        });

        // Hook to allow for any post-create quorum logic
        _afterCreateQuorum(quorumNumber);
    }

    /**
     * @notice The function to update the stakes of operators for a mirror.
     * @param stakeWeights The stake weights.
     * @param operators The operators.
     * @param operatorIds The IDs of the operators.
     * @param quorumNumber The quorum number.
     */
    function _updateOperatorsStakesForMirror(
        uint96[] memory stakeWeights,
        address[] memory operators,
        bytes32[] memory operatorIds,
        uint8 quorumNumber
    ) internal virtual {
        bytes memory singleQuorumNumber = new bytes(1);
        singleQuorumNumber[0] = bytes1(quorumNumber);
        bool[] memory doesNotMeetStakeThreshold = IMirrorStakeRegistry(address(stakeRegistry))
            .updateOperatorsStakeForMirror(stakeWeights, operators, operatorIds, quorumNumber);
        for (uint256 j = 0; j < operators.length; ++j) {
            // If the operator does not have the minimum stake, they need to be force deregistered.
            if (doesNotMeetStakeThreshold[j]) {
                _kickOperator(operators[j], singleQuorumNumber);
            }
        }
    }
}
