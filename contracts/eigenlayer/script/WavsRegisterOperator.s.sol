// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";

import {WavsRegisterOperatorLib} from "./utils/WavsRegisterOperatorLib.sol";
import {ReadCoreLib} from "./utils/ReadCoreLib.sol";

// contract WavsRegisterOperator is Script, IECDSAStakeRegistryTypes {
contract WavsRegisterOperator is Script {
    // using ReadCoreLib for *;
    // using UpgradeableProxyLib for address;

    // Environment variables for deployContracts
    string public constant ENV_LST_CONTRACT = "LST_CONTRACT_ADDRESS";
    string public constant ENV_LST_STRATEGY = "LST_STRATEGY_ADDRESS";
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";
    string public constant ENV_SIGNING_KEY = "WAVS_SIGNING_KEY";
    string public constant ENV_AMOUNT = "WAVS_DELEGATE_AMOUNT";

    // configuration
    address private lstContractAddress;
    address private lstStrategyAddress;
    address private serviceManagerAddress;
    address private signingKey;
    uint256 private stakeAmount;

    ReadCoreLib.DeploymentData public coreDeployment;

    function setUp() public virtual {
        coreDeployment = ReadCoreLib.readDeploymentJson("deployments/eigenlayer-core/", block.chainid);

        // Get the configuration from environment
        lstContractAddress = vm.envAddress(ENV_LST_CONTRACT);
        lstStrategyAddress = vm.envAddress(ENV_LST_STRATEGY);
        serviceManagerAddress = vm.envAddress(ENV_SERVICE_MANAGER);

        signingKey = vm.envAddress(ENV_SIGNING_KEY);
        stakeAmount = vm.envUint(ENV_AMOUNT);
    }

    function run() external {
        vm.startBroadcast();

        WavsRegisterOperatorLib.setupOperator(coreDeployment, lstContractAddress, lstStrategyAddress, stakeAmount);
        WavsRegisterOperatorLib.registerToAvs(serviceManagerAddress, signingKey);

        vm.stopBroadcast();
    }
}
