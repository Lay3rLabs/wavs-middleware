// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {WavsListOperatorsLib} from "script/eigenlayer/bls/utils/WavsListOperatorsLib.sol";

/**
 * @title WavsListOperators
 * @author Lay3rLabs
 * @notice This script lists the operators for the WAVS service manager.
 * @dev This script is used to list the operators for the WAVS service manager.
 */
contract WavsListOperators is Script {
    /// @notice The environment variable for the WAVS service manager address.
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";

    address private _serviceManager;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        _serviceManager = vm.envAddress(ENV_SERVICE_MANAGER);
    }

    /// @notice The run function for the script.
    function run() external {
        address[] memory operators = WavsListOperatorsLib.getOperators(_serviceManager, uint8(0));
        WavsListOperatorsLib.ConfigData memory configData =
            WavsListOperatorsLib.getConfigData(_serviceManager, uint8(0), operators);
        WavsListOperatorsLib.writeOperatorListJson(configData);
    }
}
