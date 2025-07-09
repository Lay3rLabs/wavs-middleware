// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library ReadCoreLib {
    using stdJson for *;
    using Strings for *;

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

    error ReadCoreLib__DelegationManagerAddressCannotBeZero();
    error ReadCoreLib__AVSDirectoryAddressCannotBeZero();
    error ReadCoreLib__StrategyManagerAddressCannotBeZero();
    error ReadCoreLib__EigenPodManagerAddressCannotBeZero();
    error ReadCoreLib__StrategyFactoryAddressCannotBeZero();
    error ReadCoreLib__RewardsCoordinatorAddressCannotBeZero();
    error ReadCoreLib__AllocationManagerAddressCannotBeZero();
    error ReadCoreLib__PermissionControllerAddressCannotBeZero();

    function readDeploymentJson(
        string memory deploymentPath,
        uint256 chainId
    ) internal view returns (DeploymentData memory) {
        string memory json =
            VM.readFile(string.concat(deploymentPath, uint256(chainId).toString(), ".json"));

        DeploymentData memory data;
        data = readAddressSet(json, data);
        validateDeployment(data);
        return data;
    }

    function readAddressSet(
        string memory json,
        DeploymentData memory data
    ) private pure returns (DeploymentData memory) {
        data.strategyFactory = json.readAddress(".addresses.strategyFactory");
        data.strategyManager = json.readAddress(".addresses.strategyManager");
        data.eigenPodManager = json.readAddress(".addresses.eigenPodManager");
        data.delegationManager = json.readAddress(".addresses.delegation");
        data.avsDirectory = json.readAddress(".addresses.avsDirectory");
        data.rewardsCoordinator = json.readAddress(".addresses.rewardsCoordinator");
        data.allocationManager = json.readAddress(".addresses.allocationManager");
        data.permissionController = json.readAddress(".addresses.permissionController");

        return data;
    }

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
