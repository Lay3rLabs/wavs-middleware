// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import {WavsMiddlewareDeploymentLib} from "../script/utils/WavsMiddlewareDeplomentLib.sol";
import {UpgradeableProxyLib} from "../script/utils/UpgradeableProxyLib.sol";
import {MirrorStakeRegistry} from "../src/MirrorStakeRegistry.sol";
import {WavsServiceManager} from "../src/WavsServiceManager.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IECDSAStakeRegistryTypes} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
import {IWavsServiceHandler} from "../../interfaces/IWavsServiceHandler.sol";
import {IWavsServiceManager} from "../../interfaces/IWavsServiceManager.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ECDSAUpgradeable} from "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";

uint256 constant OPERATOR_WEIGHT = 10000;

contract WavsMiddlewareDeploymentLibTest is Test {
    using UpgradeableProxyLib for address;

    function setUp() public {}

    function test_parseStrategies() public {
        IECDSAStakeRegistryTypes.Quorum memory quorum =
            WavsMiddlewareDeploymentLib.readQuorumConfig("deployments/strategies/", 17000);
        console2.log(quorum.strategies.length);
        console2.log(address(quorum.strategies[0].strategy));
        console2.log(quorum.strategies[0].multiplier);
        assertEq(quorum.strategies.length, 12);
        uint96 totalMultiplier = 0;
        for (uint256 i; i < quorum.strategies.length; i++) {
            totalMultiplier += quorum.strategies[i].multiplier;
        }
        assertEq(totalMultiplier, 10000);
    }
}
