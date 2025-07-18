// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {WavsRegisterOperatorLib} from "./utils/WavsRegisterOperatorLib.sol";
import {ReadCoreLib} from "./utils/ReadCoreLib.sol";

/**
 * @title WavsRegisterOperator
 * @author Lay3rLabs
 * @notice This script registers an operator to the WavsServiceManager contract.
 * @dev This script is used to register an operator to the WavsServiceManager contract.
 */
contract WavsRegisterOperator is Script {
    /// @notice The environment variable for the LST contract address.
    string public constant ENV_LST_CONTRACT = "LST_CONTRACT_ADDRESS";
    /// @notice The environment variable for the LST strategy address.
    string public constant ENV_LST_STRATEGY = "LST_STRATEGY_ADDRESS";
    /// @notice The environment variable for the WAVS service manager contract address.
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";
    /// @notice The environment variable for the signing key address.
    string public constant ENV_SIGNING_KEY = "WAVS_SIGNING_KEY";
    /// @notice The environment variable for the amount of stake to delegate.
    string public constant ENV_AMOUNT = "WAVS_DELEGATE_AMOUNT";

    address private lstContractAddress;
    address private lstStrategyAddress;
    address private serviceManagerAddress;
    address private signingKeyAddress;
    uint256 private stakeAmount;

    /// @notice The deployment data.
    ReadCoreLib.DeploymentData public coreDeployment;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        coreDeployment =
            ReadCoreLib.readDeploymentJson("deployments/eigenlayer-core/", block.chainid);

        // Get the configuration from environment
        lstContractAddress = vm.envAddress(ENV_LST_CONTRACT);
        lstStrategyAddress = vm.envAddress(ENV_LST_STRATEGY);
        serviceManagerAddress = vm.envAddress(ENV_SERVICE_MANAGER);

        signingKeyAddress = vm.envAddress(ENV_SIGNING_KEY);
        stakeAmount = vm.envUint(ENV_AMOUNT);
    }

    /// @notice The run function for the script.
    function run() external {
        vm.startBroadcast();

        WavsRegisterOperatorLib.setupOperator(
            coreDeployment, lstContractAddress, lstStrategyAddress, stakeAmount
        );
        WavsRegisterOperatorLib.registerToAvs(serviceManagerAddress, signingKeyAddress);

        vm.stopBroadcast();
    }
}
