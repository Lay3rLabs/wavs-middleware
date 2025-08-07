// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {WavsListOperatorsLib} from "script/eigenlayer/bls/utils/WavsListOperatorsLib.sol";

/**
 * @title WavsMirrorListOperators
 * @author Lay3rLabs
 * @notice This script lists the operators for the WAVS mirror service manager.
 * @dev This script is used to list the operators for the WAVS mirror service manager.
 */
contract WavsMirrorListOperators is Script {
    /// @notice The environment variable for the WAVS service manager address.
    string public constant ENV_MIRROR_SERVICE_MANAGER = "MIRROR_SERVICE_MANAGER_ADDRESS";
    /// @notice The environment variable for the WAVS source service manager address.
    string public constant ENV_SOURCE_SERVICE_MANAGER = "SOURCE_SERVICE_MANAGER_ADDRESS";
    /// @notice The environment variable for the WAVS source RPC URL.
    string public constant ENV_SOURCE_RPC_URL = "SOURCE_RPC_URL";
    /// @notice The environment variable for the WAVS mirror RPC URL.
    string public constant ENV_MIRROR_RPC_URL = "MIRROR_RPC_URL";

    address private _mirrorServiceManager;
    address private _sourceServiceManager;
    string private _sourceRpcUrl;
    string private _mirrorRpcUrl;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        _mirrorServiceManager = vm.envAddress(ENV_MIRROR_SERVICE_MANAGER);
        _sourceServiceManager = vm.envAddress(ENV_SOURCE_SERVICE_MANAGER);
        _sourceRpcUrl = vm.envString(ENV_SOURCE_RPC_URL);
        _mirrorRpcUrl = vm.envString(ENV_MIRROR_RPC_URL);
    }

    /// @notice The run function for the script.
    function run() external {
        vm.createSelectFork(_sourceRpcUrl);
        address[] memory operators =
            WavsListOperatorsLib.getOperators(_sourceServiceManager, uint8(0));

        vm.createSelectFork(_mirrorRpcUrl);
        WavsListOperatorsLib.ConfigData memory configData =
            WavsListOperatorsLib.getConfigData(_mirrorServiceManager, uint8(0), operators);
        WavsListOperatorsLib.writeOperatorListJson(configData);
    }
}
