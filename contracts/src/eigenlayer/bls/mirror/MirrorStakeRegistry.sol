// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ISlashingRegistryCoordinator} from
    "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IDelegationManager} from
    "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IAllocationManager} from
    "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {StakeRegistry} from "@eigenlayer-middleware/src/StakeRegistry.sol";

import {IMirrorStakeRegistry} from "../interfaces/IMirrorStakeRegistry.sol";

/**
 * @title MirrorStakeRegistry
 * @author Lay3rLabs
 * @notice This contract implements the MirrorStakeRegistry contract.
 * @dev This contract is used to register and update operators for a mirror.
 */
contract MirrorStakeRegistry is StakeRegistry, IMirrorStakeRegistry {
    /**
     * @notice The constructor for the MirrorStakeRegistry contract.
     * @param _registryCoordinator The slashing registry coordinator.
     * @param _delegationManager The delegation manager.
     * @param _avsDirectory The AVS directory.
     * @param _allocationManager The allocation manager.
     */
    constructor(
        ISlashingRegistryCoordinator _registryCoordinator,
        IDelegationManager _delegationManager,
        IAVSDirectory _avsDirectory,
        IAllocationManager _allocationManager
    ) StakeRegistry(_registryCoordinator, _delegationManager, _avsDirectory, _allocationManager) {}

    /* solhint-disable gas-calldata-parameters */
    /// @inheritdoc IMirrorStakeRegistry
    function registerOperatorForMirror(
        bytes32 operatorId,
        bytes calldata quorumNumbers,
        uint96 currentStake
    ) public onlySlashingRegistryCoordinator returns (uint96[] memory, uint96[] memory) {
        uint96[] memory currentStakes = new uint96[](quorumNumbers.length);
        uint96[] memory totalStakes = new uint96[](quorumNumbers.length);
        for (uint256 i = 0; i < quorumNumbers.length; ++i) {
            uint8 quorumNumber = uint8(quorumNumbers[i]);
            _checkQuorumExists(quorumNumber);

            // Update the operator's stake
            int256 stakeDelta = _recordOperatorStakeUpdate({
                operatorId: operatorId,
                quorumNumber: quorumNumber,
                newStake: currentStake
            });

            // Update this quorum's total stake by applying the operator's delta
            currentStakes[i] = currentStake;
            totalStakes[i] = _recordTotalStakeUpdate(quorumNumber, stakeDelta);
        }

        return (currentStakes, totalStakes);
    }

    /// @inheritdoc IMirrorStakeRegistry
    function updateOperatorsStakeForMirror(
        uint96[] memory stakeWeights,
        address[] memory operators,
        bytes32[] memory operatorIds,
        uint8 quorumNumber
    ) external onlySlashingRegistryCoordinator returns (bool[] memory) {
        bool[] memory shouldBeDeregistered = new bool[](operators.length);

        /**
         * For each quorum, update the operator's stake and record the delta
         * in the quorum's total stake.
         *
         * If the operator no longer has the minimum stake required to be registered
         * in the quorum, the quorum number is added to `quorumsToRemove`, which
         * is returned to the registry coordinator.
         */
        _checkQuorumExists(quorumNumber);

        int256 totalStakeDelta = 0;
        // If the operator no longer meets the minimum stake, set their stake to zero and mark them for removal
        /// also handle setting the operator's stake to 0 and remove them from the quorum
        for (uint256 i = 0; i < operators.length; ++i) {
            if (stakeWeights[i] < minimumStakeForQuorum[quorumNumber]) {
                stakeWeights[i] = 0;
                shouldBeDeregistered[i] = true;
            }

            // Update the operator's stake and retrieve the delta
            // If we're deregistering them, their weight is set to 0
            int256 stakeDelta = _recordOperatorStakeUpdate({
                operatorId: operatorIds[i],
                quorumNumber: quorumNumber,
                newStake: stakeWeights[i]
            });

            totalStakeDelta += stakeDelta;
        }

        // Apply the delta to the quorum's total stake
        _recordTotalStakeUpdate(quorumNumber, totalStakeDelta);

        return shouldBeDeregistered;
    }

    /// @inheritdoc StakeRegistry
    function addStrategies(
        uint8 quorumNumber,
        StrategyParams[] memory _strategyParams
    ) public override onlyCoordinatorOwner quorumExists(quorumNumber) {
        _addStrategyParams(quorumNumber, _strategyParams);
    }

    /// @inheritdoc StakeRegistry
    function removeStrategies(
        uint8 quorumNumber,
        uint256[] memory indicesToRemove
    ) public override onlyCoordinatorOwner quorumExists(quorumNumber) {
        uint256 toRemoveLength = indicesToRemove.length;
        require(toRemoveLength > 0, InputArrayLengthZero());

        StrategyParams[] storage _strategyParams = strategyParams[quorumNumber];
        IStrategy[] storage _strategiesPerQuorum = strategiesPerQuorum[quorumNumber];
        IStrategy[] memory _strategiesToRemove = new IStrategy[](toRemoveLength);

        for (uint256 i = 0; i < toRemoveLength; ++i) {
            _strategiesToRemove[i] = _strategyParams[indicesToRemove[i]].strategy;
            emit StrategyRemovedFromQuorum(
                quorumNumber, _strategyParams[indicesToRemove[i]].strategy
            );
            emit StrategyMultiplierUpdated(
                quorumNumber, _strategyParams[indicesToRemove[i]].strategy, 0
            );

            // Replace index to remove with the last item in the list, then pop the last item
            _strategyParams[indicesToRemove[i]] = _strategyParams[_strategyParams.length - 1];
            _strategyParams.pop();
            _strategiesPerQuorum[indicesToRemove[i]] =
                _strategiesPerQuorum[_strategiesPerQuorum.length - 1];
            _strategiesPerQuorum.pop();
        }
    }

    /* solhint-disable use-natspec */
    /// @inheritdoc StakeRegistry
    function _weightOfOperatorsForQuorum(
        uint8, /* quorumNumber */
        address[] memory /* operators */
    ) internal pure override returns (uint96[] memory, bool[] memory) {
        revert MirrorStakeRegistry_NotImplemented();
    }

    /// @inheritdoc StakeRegistry
    function registerOperator(
        address, /* operator */
        bytes32, /* operatorId */
        bytes calldata /* quorumNumbers */
    ) public pure override returns (uint96[] memory, uint96[] memory) {
        revert MirrorStakeRegistry_NotImplemented();
    }
}
