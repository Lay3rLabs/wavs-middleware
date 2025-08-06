// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IMirrorSlashingRegistryCoordinator
 * @author Lay3rLabs
 * @notice This interface defines the MirrorSlashingRegistryCoordinator contract.
 * @dev This interface is used to interact with the MirrorSlashingRegistryCoordinator contract.
 */
interface IMirrorSlashingRegistryCoordinator {
    /**
     * @notice The function to register an operator for a mirror.
     * @param operator The operator.
     * @param avs The AVS.
     * @param operatorSetIds The operator set IDs.
     * @param currentStake The current stake.
     * @param data The data.
     */
    function registerOperatorForMirror(
        address operator,
        address avs,
        uint32[] memory operatorSetIds,
        uint96 currentStake,
        bytes calldata data
    ) external;

    /**
     * @notice The function to update the stake of operators for a mirror.
     * @param stakeWeights The stake weights.
     * @param operators The operators.
     */
    function updateOperatorsForMirror(
        uint96[] memory stakeWeights,
        address[] memory operators
    ) external;

    /**
     * @notice The function to update the stake of operators for a quorum for a mirror.
     * @param operatorsPerQuorum The operators per quorum.
     * @param stakeWeights The stake weights.
     * @param quorumNumbers The quorum numbers.
     */
    function updateOperatorsForQuorumForMirror(
        address[][] memory operatorsPerQuorum,
        uint96[][] memory stakeWeights,
        bytes calldata quorumNumbers
    ) external;
}
