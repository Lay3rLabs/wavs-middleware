// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

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
    }

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    error ReadCoreLib__RewardsCoordinatorNotFound();

    function readDeploymentJson(
        string memory deploymentPath,
        uint256 chainId
    ) internal view returns (DeploymentData memory) {
        string memory json =
            VM.readFile(string.concat(deploymentPath, uint256(chainId).toString(), ".json"));

        DeploymentData memory data;
        data = readFirstAddressSet(json, data);
        data = readSecondAddressSet(json, data);
        return data;
    }

    function readFirstAddressSet(
        string memory json,
        DeploymentData memory data
    ) internal pure returns (DeploymentData memory) {
        data.strategyFactory = json.readAddress(".addresses.strategyFactory");
        data.strategyManager = json.readAddress(".addresses.strategyManager");
        data.eigenPodManager = json.readAddress(".addresses.eigenPodManager");
        data.delegationManager = json.readAddress(".addresses.delegation");
        return data;
    }

    function readSecondAddressSet(
        string memory json,
        DeploymentData memory data
    ) internal pure returns (DeploymentData memory) {
        data.avsDirectory = json.readAddress(".addresses.avsDirectory");

        // Try to read rewardsCoordinator
        try VM.parseJson(json, ".addresses.rewardsCoordinator") returns (bytes memory parsed) {
            if (parsed.length > 0) {
                data.rewardsCoordinator = abi.decode(parsed, (address));
            }
        } catch {
            revert ReadCoreLib__RewardsCoordinatorNotFound();
        }

        data.allocationManager = json.readAddress(".addresses.allocationManager");
        return data;
    }
}
