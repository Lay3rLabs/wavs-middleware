// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {
    IECDSAStakeRegistryTypes
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";

import {
    WavsMiddlewareDeploymentLib
} from "script/eigenlayer/ecdsa/utils/WavsMiddlewareDeploymentLib.sol";
import {UpgradeableProxyLib} from "script/eigenlayer/ecdsa/utils/UpgradeableProxyLib.sol";

uint256 constant OPERATOR_WEIGHT = 10_000;

/**
 * @title WavsMiddlewareDeploymentLibTest
 * @author Lay3rLabs
 * @notice This contract contains tests for the WavsMiddlewareDeploymentLib contract.
 * @dev This contract is used to test the WavsMiddlewareDeploymentLib contract.
 */
contract WavsMiddlewareDeploymentLibTest is Test {
    using UpgradeableProxyLib for address;

    /// @notice The setUp function.
    function setUp() public {}

    /* solhint-disable func-name-mixedcase */
    /// @notice The test_parseStrategies function.
    function test_parseStrategies() public {
        /* solhint-enable func-name-mixedcase */
        IECDSAStakeRegistryTypes.Quorum memory quorum =
            WavsMiddlewareDeploymentLib.readQuorumConfig("deployments/strategies/", 17_000);
        console2.log(quorum.strategies.length);
        console2.log(address(quorum.strategies[0].strategy));
        console2.log(quorum.strategies[0].multiplier);
        assertEq(quorum.strategies.length, 12);
        uint96 totalMultiplier = 0;
        for (uint256 i; i < quorum.strategies.length; ++i) {
            totalMultiplier += quorum.strategies[i].multiplier;
        }
        assertEq(totalMultiplier, 10_000);
    }
}
