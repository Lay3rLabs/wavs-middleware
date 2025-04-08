// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
import {LayerMiddlewareDeploymentLib} from "./utils/LayerMiddlewareDeplomentLib.sol";
import {ReadCoreLib} from "./utils/ReadCoreLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";
import {StrategyBase} from "@eigenlayer/contracts/strategies/StrategyBase.sol";
import {ERC20Mock} from "../test/ERC20Mock.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {StrategyFactory} from "@eigenlayer/contracts/strategies/StrategyFactory.sol";
import {StrategyManager} from "@eigenlayer/contracts/core/StrategyManager.sol";


import {
    IECDSAStakeRegistryTypes,
    IStrategy
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";

contract WavsMiddlewareDeployer is Script, IECDSAStakeRegistryTypes {
    using ReadCoreLib for *;
    using UpgradeableProxyLib for address;

    address private deployer;
    address proxyAdmin;
    IStrategy helloWorldStrategy;
    ReadCoreLib.DeploymentData coreDeployment;
    WavsMiddlewareDeploymentLib.DeploymentData wavsMiddlewareDeployment;
    Quorum internal quorum;
    ERC20Mock token;
    function setUp() public virtual {
        deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        vm.label(deployer, "Deployer");

        coreDeployment = ReadCoreLib.readDeploymentJson("deployments/core/", block.chainid);
       
        token = new ERC20Mock();
        helloWorldStrategy = IStrategy(StrategyFactory(coreDeployment.strategyFactory).deployNewStrategy(token));

        quorum.strategies.push(
            StrategyParams({strategy: helloWorldStrategy, multiplier: 10_000})
        );
    }

    function run() external {
        vm.startBroadcast(deployer);
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        wavsMiddlewareDeployment =
            WavsMiddlewareDeploymentLib.deployContracts(proxyAdmin, coreDeployment, quorum);

        wavsMiddlewareDeployment.strategy = address(helloWorldStrategy);
        wavsMiddlewareDeployment.token = address(token);
        vm.stopBroadcast();

        verifyDeployment();
        WavsMiddlewareDeploymentLib.writeDeploymentJson(wavsMiddlewareDeployment);
    }

    function verifyDeployment() internal view {
        require(
            wavsMiddlewareDeployment.stakeRegistry != address(0), "StakeRegistry address cannot be zero"
        );
        require(
            wavsMiddlewareDeployment.WavsServiceManager != address(0),
            "WavsServiceManager address cannot be zero"
        );
        require(wavsMiddlewareDeployment.strategy != address(0), "Strategy address cannot be zero");
        require(proxyAdmin != address(0), "ProxyAdmin address cannot be zero");
        require(
            coreDeployment.delegationManager != address(0),
            "DelegationManager address cannot be zero"
        );
        require(coreDeployment.avsDirectory != address(0), "AVSDirectory address cannot be zero");
    }
}
