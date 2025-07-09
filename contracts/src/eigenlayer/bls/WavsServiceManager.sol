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

contract WavsServiceManager is ServiceManagerBase, IWavsServiceManager {
    string public serviceURI;
    uint256 public quorumNumerator;
    uint256 public quorumDenominator;

    constructor(
        address __avsDirectory,
        address __rewardsCoordinator,
        address __registryCoordinator,
        address __stakeRegistry,
        address __permissionController,
        address __allocationManager
    )
        ServiceManagerBase(
            IAVSDirectory(__avsDirectory),
            IRewardsCoordinator(__rewardsCoordinator),
            ISlashingRegistryCoordinator(__registryCoordinator),
            IStakeRegistry(__stakeRegistry),
            IPermissionController(__permissionController),
            IAllocationManager(__allocationManager)
        )
    {}

    function initialize(address initialOwner, address rewardsInitiator) external initializer {
        __ServiceManagerBase_init(initialOwner, rewardsInitiator);

        quorumNumerator = 2;
        quorumDenominator = 3;
    }

    /// @notice Slashes an operator
    function slashOperator(
        IAllocationManager.SlashingParams memory params
    ) external {
        // Implementation logic here
    }

    function setServiceURI(
        string calldata _serviceURI
    ) external onlyOwner {
        serviceURI = _serviceURI;
        emit ServiceURIUpdated(_serviceURI);
    }

    function getServiceURI() external view returns (string memory) {
        return serviceURI;
    }

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

    /**
     * @notice Updates the metadata URI for the AVS
     * @param _metadataURI is the metadata URI for the AVS
     * @dev only callable by the owner
     */
    function updateAVSMetadataURI(
        string memory _metadataURI
    ) public override onlyOwner {
        _avsDirectory.updateAVSMetadataURI(_metadataURI);
        _allocationManager.updateAVSMetadataURI(address(this), _metadataURI);
    }

    function getRegistryCoordinator() external view returns (address) {
        return address(_registryCoordinator);
    }

    function getAllocationManager() external view returns (address) {
        return address(_allocationManager);
    }

    function getStakeRegistry() external view returns (address) {
        return address(_stakeRegistry);
    }
}
