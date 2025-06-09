// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
import {WavsMirrorDeploymentLib} from "./utils/WavsMirrorDeploymentLib.sol";
import {ReadCoreLib} from "./utils/ReadCoreLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";
import {StrategyBase} from "@eigenlayer/contracts/strategies/StrategyBase.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {StrategyFactory} from "@eigenlayer/contracts/strategies/StrategyFactory.sol";
import {StrategyManager} from "@eigenlayer/contracts/core/StrategyManager.sol";


import {
    IECDSAStakeRegistryTypes,
    IStrategy
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";

contract WavsMirrorDeployer is Script, IECDSAStakeRegistryTypes {
    using ReadCoreLib for *;
    using UpgradeableProxyLib for address;

    address private deployer;
    address proxyAdmin;
    IStrategy helloWorldStrategy;
    ReadCoreLib.DeploymentData coreDeployment;
    WavsMirrorDeploymentLib.DeploymentData WavsMirrorDeployment;

    function setUp() public virtual {
        deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        vm.label(deployer, "Mirror Deployer");
    }

    function run() external {
        vm.startBroadcast(deployer);
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        WavsMirrorDeployment =
            WavsMirrorDeploymentLib.deployContracts(proxyAdmin);
        vm.stopBroadcast();

        verifyDeployment();
        WavsMirrorDeploymentLib.writeDeploymentJson(WavsMirrorDeployment);
    }

    function verifyDeployment() internal view {
        require(
            WavsMirrorDeployment.stakeRegistry != address(0), "StakeRegistry address cannot be zero"
        );
        require(
            WavsMirrorDeployment.WavsServiceManager != address(0),
            "WavsServiceManager address cannot be zero"
        );
        require(proxyAdmin != address(0), "ProxyAdmin address cannot be zero");
    }
}
