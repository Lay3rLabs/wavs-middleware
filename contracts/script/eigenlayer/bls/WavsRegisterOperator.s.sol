// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {WavsRegisterOperatorLib} from "./utils/WavsRegisterOperatorLib.sol";
import {ReadCoreLib} from "./utils/ReadCoreLib.sol";

contract WavsRegisterOperator is Script {
    // Environment variables for deployContracts
    string public constant ENV_LST_CONTRACT = "LST_CONTRACT_ADDRESS";
    string public constant ENV_LST_STRATEGY = "LST_STRATEGY_ADDRESS";
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";
    string public constant ENV_AMOUNT = "WAVS_DELEGATE_AMOUNT";
    string public constant ENV_OPERATOR_KEY = "OPERATOR_KEY";
    // configuration
    address private _lstContractAddress;
    address private _lstStrategyAddress;
    address private _serviceManagerAddress;
    uint256 private _stakeAmount;
    uint256 private _operatorKey;
    ReadCoreLib.DeploymentData public coreDeployment;

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
