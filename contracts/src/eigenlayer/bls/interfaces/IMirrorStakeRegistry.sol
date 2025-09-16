// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IMirrorStakeRegistry
 * @author Lay3rLabs
 * @notice This interface defines the MirrorStakeRegistry contract.
 * @dev This interface is used to interact with the MirrorStakeRegistry contract.
 */
interface IMirrorStakeRegistry {
    /// @notice The error thrown when the function is not implemented.
    error MirrorStakeRegistry_NotImplemented();

    /**
     * @notice The function to register an operator for a mirror.
     * @param operatorId The ID of the operator.
     * @param quorumNumbers The quorum numbers.
     * @param currentStake The current stake.
     * @return currentStakes The current stakes.
     * @return totalStakes The total stakes.
     */
    function registerOperatorForMirror(
        bytes32 operatorId,
        bytes calldata quorumNumbers,
        uint96 currentStake
    ) external returns (uint96[] memory, uint96[] memory);

    /**
     * @notice The function to update the stake of operators for a mirror.
     * @param stakeWeights The stake weights.
     * @param operators The operators.
     * @param operatorIds The IDs of the operators.
     * @param quorumNumber The quorum number.
     * @return results The results.
     */
    function updateOperatorsStakeForMirror(
        uint96[] memory stakeWeights,
        address[] memory operators,
        bytes32[] memory operatorIds,
        uint8 quorumNumber
    ) external returns (bool[] memory);
}
