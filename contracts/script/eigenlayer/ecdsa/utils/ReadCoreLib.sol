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
    }

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

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
        return data;
    }
}
