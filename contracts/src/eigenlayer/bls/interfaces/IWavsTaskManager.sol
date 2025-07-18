// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";

/**
 * @title IWavsTaskManager
 * @author Lay3r Labs
 * @notice Interface for the Wavs task manager
 * @dev This interface is used to interact with the Wavs task manager
 */
interface IWavsTaskManager {
    /**
     * @notice Emitted when a new task is created
     * @param taskIndex The index of the task
     * @param task The task
     */
    event NewTaskCreated(uint32 indexed taskIndex, Task task);

    /**
     * @notice Emitted when a task is responded to
     * @param taskResponse The task response
     * @param taskResponseMetadata The task response metadata
     */
    event TaskResponded(TaskResponse taskResponse, TaskResponseMetadata taskResponseMetadata);

    /**
     * @notice Emitted when a task is completed
     * @param taskIndex The index of the task
     */
    event TaskCompleted(uint32 indexed taskIndex);

    /**
     * @notice Emitted when a task is challenged successfully
     * @param taskIndex The index of the task
     * @param challenger The address of the challenger
     */
    event TaskChallengedSuccessfully(uint32 indexed taskIndex, address indexed challenger);

    /**
     * @notice Emitted when a task is challenged unsuccessfully
     * @param taskIndex The index of the task
     * @param challenger The address of the challenger
     */
    event TaskChallengedUnsuccessfully(uint32 indexed taskIndex, address indexed challenger);

    /// @notice Error thrown when the caller is not the aggregator
    error WavsTaskManager__OnlyAggregator();
    /// @notice Error thrown when the caller is not the task generator
    error WavsTaskManager__OnlyTaskGenerator();
    /// @notice Error thrown when the supplied task does not match one recorded in the contract
    error WavsTaskManager__SuppliedTaskDoesNotMatchOneRecordedInContract();
    /// @notice Error thrown when the aggregator has already responded to the task
    error WavsTaskManager__AggregatorHasAlreadyRespondedToTask();
    /// @notice Error thrown when the aggregator has responded to the task too late
    error WavsTaskManager__AggregatorHasRespondedToTaskTooLate();
    /// @notice Error thrown when the signatories do not own at least the threshold percentage of a quorum
    error WavsTaskManager__SignatoriesDoNotOwnAtLeastThresholdPercentageOfAQuorum();
    /// @notice Error thrown when the task response does not match one recorded in the contract
    error WavsTaskManager__TaskResponseDoesNotMatchOneRecordedInContract();
    /// @notice Error thrown when the response to this task has been challenged successfully
    error WavsTaskManager__ResponseToThisTaskHasBeenChallengedSuccessfully();
    /// @notice Error thrown when the challenge period for this task has already expired
    error WavsTaskManager__ChallengePeriodForThisTaskHasAlreadyExpired();
    /// @notice Error thrown when the task has not been responded to yet
    error WavsTaskManager__TaskHasNotBeenRespondedToYet();
    /// @notice Error thrown when the pubkeys of non-signing operators supplied by the challenger are not correct
    error WavsTaskManager__PubkeysOfNonSigningOperatorsSuppliedByChallengerAreNotCorrect();

    /**
     * @notice Task struct
     * @param numberToBeSquared The number to be squared
     * @param taskCreatedBlock The block number when the task was created
     * @param quorumThresholdPercentage The quorum threshold percentage
     * @param quorumNumbers The quorum numbers
     */
    struct Task {
        uint256 numberToBeSquared;
        uint32 taskCreatedBlock;
        uint32 quorumThresholdPercentage;
        bytes quorumNumbers;
    }

    /**
     * @notice Task response struct
     * @param referenceTaskIndex The index of the task
     * @param numberSquared The number squared
     */
    struct TaskResponse {
        uint32 referenceTaskIndex;
        uint256 numberSquared;
    }

    /**
     * @notice Task response metadata struct
     * @param taskResponsedBlock The block number when the task was responded to
     * @param hashOfNonSigners The hash of the non-signers
     */
    struct TaskResponseMetadata {
        uint32 taskResponsedBlock;
        bytes32 hashOfNonSigners;
    }

    /**
     * @notice Creates a new task
     * @param numberToBeSquared The number to be squared
     * @param quorumThresholdPercentage The quorum threshold percentage
     * @param quorumNumbers The quorum numbers
     */
    function createNewTask(
        uint256 numberToBeSquared,
        uint32 quorumThresholdPercentage,
        bytes calldata quorumNumbers
    ) external;

    /**
     * @notice Returns the current 'taskNumber' for the middleware
     * @return The current 'taskNumber'
     */
    function taskNumber() external view returns (uint32);

    /**
     * @notice Raises and resolves a challenge to an existing task
     * @param task The task
     * @param taskResponse The task response
     * @param taskResponseMetadata The task response metadata
     * @param pubkeysOfNonSigningOperators The pubkeys of the non-signing operators
     */
    function raiseAndResolveChallenge(
        Task calldata task,
        TaskResponse calldata taskResponse,
        TaskResponseMetadata calldata taskResponseMetadata,
        BN254.G1Point[] memory pubkeysOfNonSigningOperators
    ) external;

    /**
     * @notice Returns the TASK_RESPONSE_WINDOW_BLOCK
     * @return The TASK_RESPONSE_WINDOW_BLOCK
     */
    function getTaskResponseWindowBlock() external view returns (uint32);
}
