// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ReadCoreLib
 * @author Lay3rLabs
 * @notice This library contains functions for reading the core deployment data.
 * @dev This library is used to read the core deployment data.
 */
library ReadCoreLib {
    using stdJson for *;
    using Strings for *;

    /**
     * @notice The deployment data struct.
     * @param delegationManager The delegation manager address.
     * @param avsDirectory The AVS directory address.
     * @param strategyManager The strategy manager address.
     * @param eigenPodManager The eigen pod manager address.
     * @param strategyFactory The strategy factory address.
     * @param rewardsCoordinator The rewards coordinator address.
     * @param allocationManager The allocation manager address.
     */
    struct DeploymentData {
        address delegationManager;
        address avsDirectory;
        address strategyManager;
        address eigenPodManager;
        address strategyFactory;
        address rewardsCoordinator;
        address allocationManager;
        address permissionController;
    }

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice The error for the delegation manager address cannot be zero.
    error ReadCoreLib__DelegationManagerAddressCannotBeZero();
    /// @notice The error for the AVS directory address cannot be zero.
    error ReadCoreLib__AVSDirectoryAddressCannotBeZero();
    /// @notice The error for the strategy manager address cannot be zero.
    error ReadCoreLib__StrategyManagerAddressCannotBeZero();
    /// @notice The error for the eigen pod manager address cannot be zero.
    error ReadCoreLib__EigenPodManagerAddressCannotBeZero();
    /// @notice The error for the strategy factory address cannot be zero.
    error ReadCoreLib__StrategyFactoryAddressCannotBeZero();
    /// @notice The error for the rewards coordinator address cannot be zero.
    error ReadCoreLib__RewardsCoordinatorAddressCannotBeZero();
    /// @notice The error for the allocation manager address cannot be zero.
    error ReadCoreLib__AllocationManagerAddressCannotBeZero();
    /// @notice The error for the permission controller address cannot be zero.
    error ReadCoreLib__PermissionControllerAddressCannotBeZero();

    /**
     * @notice The read deployment JSON function.
     * @param deploymentPath The deployment path.
     * @param chainId The chain ID.
     * @return data The deployment data.
     */
    function readDeploymentJson(
        string memory deploymentPath,
        uint256 chainId
    ) internal view returns (DeploymentData memory) {
        string memory json =
            VM.readFile(string.concat(deploymentPath, uint256(chainId).toString(), ".json"));

        DeploymentData memory data;
        data.strategyFactory = json.readAddress(".addresses.strategyFactory");
        data.strategyManager = json.readAddress(".addresses.strategyManager");
        data.eigenPodManager = json.readAddress(".addresses.eigenPodManager");
        data.delegationManager = json.readAddress(".addresses.delegation");
        data.avsDirectory = json.readAddress(".addresses.avsDirectory");
        data.rewardsCoordinator = json.readAddress(".addresses.rewardsCoordinator");
        data.allocationManager = json.readAddress(".addresses.allocationManager");
        data.permissionController = json.readAddress(".addresses.permissionController");
        validateDeployment(data);
        return data;
    }

    /**
     * @notice The validate deployment function.
     * @param data The deployment data.
     */
    function validateDeployment(
        DeploymentData memory data
    ) private pure {
        if (data.delegationManager == address(0)) {
            revert ReadCoreLib__DelegationManagerAddressCannotBeZero();
        }
        if (data.avsDirectory == address(0)) {
            revert ReadCoreLib__AVSDirectoryAddressCannotBeZero();
        }
        if (data.strategyManager == address(0)) {
            revert ReadCoreLib__StrategyManagerAddressCannotBeZero();
        }
        if (data.eigenPodManager == address(0)) {
            revert ReadCoreLib__EigenPodManagerAddressCannotBeZero();
        }
        if (data.strategyFactory == address(0)) {
            revert ReadCoreLib__StrategyFactoryAddressCannotBeZero();
        }
        if (data.rewardsCoordinator == address(0)) {
            revert ReadCoreLib__RewardsCoordinatorAddressCannotBeZero();
        }
        if (data.allocationManager == address(0)) {
            revert ReadCoreLib__AllocationManagerAddressCannotBeZero();
        }
        if (data.permissionController == address(0)) {
            revert ReadCoreLib__PermissionControllerAddressCannotBeZero();
        }
    }
}
