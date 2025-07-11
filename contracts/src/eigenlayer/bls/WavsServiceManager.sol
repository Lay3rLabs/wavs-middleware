// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {ServiceManagerBase} from "@eigenlayer-middleware/src/ServiceManagerBase.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {ISlashingRegistryCoordinator} from
    "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";

import {IWavsServiceManager} from "./interfaces/IWavsServiceManager.sol";
import {IWavsTaskManager} from "./interfaces/IWavsTaskManager.sol";

contract WavsServiceManager is ServiceManagerBase, IWavsServiceManager {
    IWavsTaskManager public immutable WAVS_TASK_MANAGER;
    string public serviceURI;

    /// @notice The numerator of the quorum threshold
    uint256 public quorumNumerator;

    /// @notice The denominator of the quorum threshold
    uint256 public quorumDenominator;

    modifier onlyWavsTaskManager() {
        require(msg.sender == address(WAVS_TASK_MANAGER), WavsServiceManager__OnlyWavsTaskManager());
        _;
    }

    constructor(
        address __avsDirectory,
        address __rewardsCoordinator,
        address __registryCoordinator,
        address __stakeRegistry,
        address __permissionController,
        address __allocationManager,
        address __wavsTaskManager
    )
        ServiceManagerBase(
            IAVSDirectory(__avsDirectory),
            IRewardsCoordinator(__rewardsCoordinator),
            ISlashingRegistryCoordinator(__registryCoordinator),
            IStakeRegistry(__stakeRegistry),
            IPermissionController(__permissionController),
            IAllocationManager(__allocationManager)
        )
    {
        WAVS_TASK_MANAGER = IWavsTaskManager(__wavsTaskManager);
    }

    /**
     * @notice Initializes the contract
     * @param initialOwner The initial owner of the contract
     * @param rewardsInitiator The address of the rewards initiator
     */
    function initialize(address initialOwner, address rewardsInitiator) external initializer {
        __ServiceManagerBase_init(initialOwner, rewardsInitiator);

        quorumNumerator = 2;
        quorumDenominator = 3;
    }

    /**
     * @notice Slashes an operator
     * @param params The parameters for the slashing
     */
    function slashOperator(
        IAllocationManager.SlashingParams calldata params
    ) external {
        // Implementation logic here
    }

    /// @inheritdoc IWavsServiceManager
    function setServiceURI(
        string calldata _serviceURI
    ) external onlyOwner {
        serviceURI = _serviceURI;
        emit ServiceURIUpdated(_serviceURI);
    }

    /// @inheritdoc IWavsServiceManager
    function getServiceURI() external view returns (string memory) {
        return serviceURI;
    }

    /// @inheritdoc IWavsServiceManager
    function setQuorumThreshold(uint256 numerator, uint256 denominator) external onlyOwner {
        if (numerator == 0) {
            revert InvalidQuorumParameters();
        }
        if (denominator == 0) {
            revert InvalidQuorumParameters();
        }
        if (numerator > denominator) {
            revert InvalidQuorumParameters();
        }

        quorumNumerator = numerator;
        quorumDenominator = denominator;

        emit QuorumThresholdUpdated(numerator, denominator);
    }

    /// @inheritdoc ServiceManagerBase
    function updateAVSMetadataURI(
        string memory _metadataURI
    ) public override onlyOwner {
        _allocationManager.updateAVSMetadataURI(address(this), _metadataURI);
    }

    /// @inheritdoc IWavsServiceManager
    function getRegistryCoordinator() external view returns (address) {
        return address(_registryCoordinator);
    }

    /// @inheritdoc IWavsServiceManager
    function getAllocationManager() external view returns (address) {
        return address(_allocationManager);
    }

    /// @inheritdoc IWavsServiceManager
    function getStakeRegistry() external view returns (address) {
        return address(_stakeRegistry);
    }
}
