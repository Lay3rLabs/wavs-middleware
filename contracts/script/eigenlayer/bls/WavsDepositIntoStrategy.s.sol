// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {ReadCoreLib} from "./utils/ReadCoreLib.sol";
import {WavsDepositIntoStrategyLib} from "./utils/WavsDepositIntoStrategyLib.sol";

/**
 * @title WavsDepositIntoStrategy
 * @author Lay3rLabs
 * @notice This script deposits into a WAVS strategy.
 * @dev This script is used to deposit into a WAVS strategy.
 */
contract WavsDepositIntoStrategy is Script {
    /// @notice The environment variable for the LST contract address.
    string public constant ENV_LST_CONTRACT = "LST_CONTRACT_ADDRESS";
    /// @notice The environment variable for the LST strategy address.
    string public constant ENV_LST_STRATEGY = "LST_STRATEGY_ADDRESS";
    /// @notice The environment variable for the amount to delegate.
    string public constant ENV_AMOUNT = "WAVS_DELEGATE_AMOUNT";

    address private _strategyManager;
    address private _delegationManager;
    address private _lstContractAddress;
    address private _lstStrategyAddress;
    uint256 private _stakeAmount;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        ReadCoreLib.DeploymentData memory coreDeployment =
            ReadCoreLib.readDeploymentJson("deployments/eigenlayer-core/", block.chainid);

        _strategyManager = coreDeployment.strategyManager;
        _delegationManager = coreDeployment.delegationManager;

        // Get the configuration from environment
        _lstContractAddress = vm.envAddress(ENV_LST_CONTRACT);
        _lstStrategyAddress = vm.envAddress(ENV_LST_STRATEGY);
        _stakeAmount = vm.envUint(ENV_AMOUNT);
    }

    /// @notice The run function for the script.
    function run() external {
        vm.startBroadcast();

        (, address operatorAddr,) = vm.readCallers();

        WavsDepositIntoStrategyLib.depositIntoStrategy(
            _strategyManager,
            _delegationManager,
            _lstContractAddress,
            _lstStrategyAddress,
            operatorAddr,
            _stakeAmount
        );

        vm.stopBroadcast();
    }
}
