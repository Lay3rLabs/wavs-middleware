// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {WavsRegisterOperatorLib} from "./utils/WavsRegisterOperatorLib.sol";
import {ReadCoreLib} from "./utils/ReadCoreLib.sol";

/**
 * @title WavsRegisterOperator
 * @author Lay3rLabs
 * @notice This script registers an operator to the WAVS service manager.
 * @dev This script is used to register an operator to the WAVS service manager.
 */
contract WavsRegisterOperator is Script {
    /// @notice The environment variable for the LST contract address.
    string public constant ENV_LST_CONTRACT = "LST_CONTRACT_ADDRESS";
    /// @notice The environment variable for the LST strategy address.
    string public constant ENV_LST_STRATEGY = "LST_STRATEGY_ADDRESS";
    /// @notice The environment variable for the WAVS service manager address.
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";
    /// @notice The environment variable for the amount to delegate.
    string public constant ENV_AMOUNT = "WAVS_DELEGATE_AMOUNT";
    /// @notice The environment variable for the operator key.
    string public constant ENV_OPERATOR_KEY = "OPERATOR_KEY";

    address private _lstContractAddress;
    address private _lstStrategyAddress;
    address private _serviceManagerAddress;
    uint256 private _stakeAmount;
    uint256 private _operatorKey;

    /// @notice The core deployment data.
    ReadCoreLib.DeploymentData public coreDeployment;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        coreDeployment =
            ReadCoreLib.readDeploymentJson("deployments/eigenlayer-core/", block.chainid);

        // Get the configuration from environment
        _lstContractAddress = vm.envAddress(ENV_LST_CONTRACT);
        _lstStrategyAddress = vm.envAddress(ENV_LST_STRATEGY);
        _serviceManagerAddress = vm.envAddress(ENV_SERVICE_MANAGER);
        _stakeAmount = vm.envUint(ENV_AMOUNT);
        _operatorKey = vm.envUint(ENV_OPERATOR_KEY);
    }

    /// @notice The run function for the script.
    function run() external {
        vm.startBroadcast();

        WavsRegisterOperatorLib.setupOperator(
            coreDeployment, _lstContractAddress, _lstStrategyAddress, _stakeAmount
        );
        WavsRegisterOperatorLib.registerToAvs(
            _operatorKey,
            _serviceManagerAddress,
            coreDeployment.allocationManager,
            _lstStrategyAddress
        );

        vm.stopBroadcast();
    }
}
