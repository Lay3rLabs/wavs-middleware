// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {WavsMirrorDeploymentLib} from "../script/utils/WavsMirrorDeploymentLib.sol";
import {UpgradeableProxyLib} from "../script/utils/UpgradeableProxyLib.sol";
import {MirrorStakeRegistry} from "../src/MirrorStakeRegistry.sol";
import {WavsServiceManager} from "../src/WavsServiceManager.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IECDSAStakeRegistryTypes} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";

contract WavsMirrorDeploymentLibTest is Test {
    using UpgradeableProxyLib for address;

    address private deployer;
    address private proxyAdmin;
    WavsMirrorDeploymentLib.DeploymentData private deployment;

    function setUp() public {
        // Set up deployer address
        deployer = address(0x123);
        vm.startPrank(deployer);
        
        // Deploy proxy admin
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();
        
        // Deploy contracts
        deployment = WavsMirrorDeploymentLib.deployContracts(proxyAdmin);
        
        vm.stopPrank();
    }
    
    function test_initial_state() public view {
        // Verify deployment addresses are set correctly
        assertNotEq(deployment.stakeRegistry, address(0), "StakeRegistry address cannot be zero");
        assertNotEq(deployment.WavsServiceManager, address(0), "WavsServiceManager address cannot be zero");
        assertNotEq(proxyAdmin, address(0), "ProxyAdmin address cannot be zero");
        
        // Verify proxy admin relationships
        address stakeRegistryProxyAdmin = address(
            UpgradeableProxyLib.getProxyAdmin(deployment.stakeRegistry)
        );
        address serviceManagerProxyAdmin = address(
            UpgradeableProxyLib.getProxyAdmin(deployment.WavsServiceManager)
        );
        
        assertEq(stakeRegistryProxyAdmin, proxyAdmin, "StakeRegistry proxy admin should match");
        assertEq(serviceManagerProxyAdmin, proxyAdmin, "WavsServiceManager proxy admin should match");
        
        // Check implementation addresses
        address stakeRegistryImpl = deployment.stakeRegistry.getImplementation();
        address serviceManagerImpl = deployment.WavsServiceManager.getImplementation();
        
        assertNotEq(stakeRegistryImpl, address(0), "StakeRegistry implementation cannot be zero");
        assertNotEq(serviceManagerImpl, address(0), "WavsServiceManager implementation cannot be zero");
        
        // Verify contract relationships
        MirrorStakeRegistry registry = MirrorStakeRegistry(deployment.stakeRegistry);
        // WavsServiceManager serviceManager = WavsServiceManager(deployment.WavsServiceManager);
        
        assertEq(address(registry.serviceManager()), deployment.WavsServiceManager, "StakeRegistry should reference ServiceManager");
        // TODO: owner is not deployer or proxyAdmin, how to fix?
        // assertEq(registry.owner(), proxyAdmin, "StakeRegistry owner should be proxyAdmin");
        // assertEq(serviceManager.owner(), proxyAdmin, "WavsServiceManager owner should be proxyAdmin");
        
        // Verify that the mock strategy is included in the quorum
        IECDSAStakeRegistryTypes.Quorum memory quorum = registry.quorum();
        assertEq(quorum.strategies.length, 1, "Quorum should have one strategy");
        assertEq(address(quorum.strategies[0].strategy), address(1), "Quorum strategy should be our mock strategy");
    }
}
