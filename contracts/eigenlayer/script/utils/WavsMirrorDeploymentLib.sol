// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {MirrorStakeRegistry} from "../../src/MirrorStakeRegistry.sol";
import {WavsServiceManager} from "../../src/WavsServiceManager.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {
    IECDSAStakeRegistryTypes,
    IStrategy
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library WavsMirrorDeploymentLib {
    using stdJson for *;
    using Strings for *;
    using UpgradeableProxyLib for address;

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct DeploymentData {
        address WavsServiceManager;
        address stakeRegistry;
    }

    function deployContracts(
        address proxyAdmin
    ) internal returns (DeploymentData memory) {
        DeploymentData memory result;

        // use an mock quorum so checks pass, we don't use it internally
        IStrategy mockStrategyInstance = IStrategy(address(1)); // Using address(1) instead of address(0)
        IECDSAStakeRegistryTypes.StrategyParams memory strategyParams = IECDSAStakeRegistryTypes.StrategyParams({
            strategy: mockStrategyInstance,
            multiplier: 10000 // 100% in basis points
        });
        IECDSAStakeRegistryTypes.StrategyParams[] memory strategies = new IECDSAStakeRegistryTypes.StrategyParams[](1);
        strategies[0] = strategyParams;
        IECDSAStakeRegistryTypes.Quorum memory quorum = IECDSAStakeRegistryTypes.Quorum({strategies: strategies});

        // First, deploy upgradeable proxy contracts that will point to the implementations.
        result.WavsServiceManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.stakeRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        // Deploy the implementation contracts, using the proxy contracts as inputs
        address stakeRegistryImpl =
            address(new MirrorStakeRegistry());
        // Use 0 address for contracts we don't use
        address WavsServiceManagerImpl = address(
            new WavsServiceManager(
                address(0),
                result.stakeRegistry,
                address(0),
                address(0),
                address(0)
            )
        );
        // Upgrade contracts
        bytes memory stakeRegistryUpgradeCall = abi.encodeCall(
            MirrorStakeRegistry.initialize, (result.WavsServiceManager, 100, quorum) // TODO: dynamically update threshold (?)
        );
        bytes memory WavsServiceManagerUpgradeCall = abi.encodeCall(
            WavsServiceManager.initialize, (msg.sender, msg.sender)
        );
        UpgradeableProxyLib.upgradeAndCall(result.stakeRegistry, stakeRegistryImpl, stakeRegistryUpgradeCall);
        UpgradeableProxyLib.upgradeAndCall(result.WavsServiceManager, WavsServiceManagerImpl, WavsServiceManagerUpgradeCall);

        // TODO: This is incredibly stupid, 
        // when we implement out own stake registry, pass owner as an argument
        bytes memory stakeRegistryOwnerUpgradeCall = abi.encodeCall(
            Ownable.transferOwnership, (msg.sender)
        );
        UpgradeableProxyLib.upgradeAndCall(result.stakeRegistry, stakeRegistryImpl, stakeRegistryOwnerUpgradeCall);

        return result;
    }

    function readDeploymentJson(
        uint256 chainId
    ) internal returns (DeploymentData memory) {
        return readDeploymentJson("deployments/wavs-mirror/", chainId);
    }

    function readDeploymentJson(
        string memory directoryPath,
        uint256 chainId
    ) internal returns (DeploymentData memory) {
        string memory fileName = string.concat(directoryPath, vm.toString(chainId), ".json");

        require(vm.exists(fileName), "Deployment file does not exist");

        string memory json = vm.readFile(fileName);

        DeploymentData memory data;
        /// TODO: 2 Step for reading deployment json.  Read to the core and the AVS data
        data.WavsServiceManager = json.readAddress(".contracts.WavsServiceManager");
        data.stakeRegistry = json.readAddress(".contracts.stakeRegistry");
        
        return data;
    }

    /// write to default output path
    function writeDeploymentJson(
        DeploymentData memory data
    ) internal {
        writeDeploymentJson("deployments/wavs-mirror/", block.chainid, data);
    }

    function writeDeploymentJson(
        string memory outputPath,
        uint256 chainId,
        DeploymentData memory data
    ) internal {
        address proxyAdmin =
            address(UpgradeableProxyLib.getProxyAdmin(data.WavsServiceManager));

        string memory deploymentData = _generateDeploymentJson(data, proxyAdmin);

        string memory fileName = string.concat(outputPath, vm.toString(chainId), ".json");
        if (!vm.exists(outputPath)) {
            vm.createDir(outputPath, true);
        }

        vm.writeFile(fileName, deploymentData);
        console2.log("Deployment artifacts written to:", fileName);
    }

    function _generateDeploymentJson(
        DeploymentData memory data,
        address proxyAdmin
    ) private view returns (string memory) {
        return string.concat(
            '{',
                '"lastUpdate":{',
                    '"timestamp":"', vm.toString(block.timestamp), '",',
                    '"block_number":"', vm.toString(block.number), '"',
                '},',
                '"addresses":', 
                    _generateContractsJson(data, proxyAdmin),
            '}'
        );
    }

    function _generateContractsJson(
        DeploymentData memory data,
        address proxyAdmin
    ) private view returns (string memory) {
        return string.concat(
            '{"proxyAdmin":"',
            proxyAdmin.toHexString(),
            '","WavsServiceManager":"',
            data.WavsServiceManager.toHexString(),
            '","WavsServiceManagerImpl":"',
            data.WavsServiceManager.getImplementation().toHexString(),
            '","stakeRegistry":"',
            data.stakeRegistry.toHexString(),
            '","stakeRegistryImpl":"',
            data.stakeRegistry.getImplementation().toHexString(),
            '"}'
        );
    }
}
