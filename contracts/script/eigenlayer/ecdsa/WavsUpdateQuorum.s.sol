// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {WavsServiceManager} from "src/eigenlayer/ecdsa/WavsServiceManager.sol";

/**
 * @title WavsUpdateQuorum
 * @author Lay3rLabs
 * @notice This script updates the quorum threshold for the WavsServiceManager contract.
 * @dev This script is used to update the quorum threshold for the WavsServiceManager contract.
 */
contract WavsUpdateQuorum is Script {
    /// @notice The environment variable for the WavsServiceManager contract address.
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";
    /// @notice The environment variable for the quorum numerator.
    string public constant ENV_QUORUM_NUMERATOR = "QUORUM_NUMERATOR";
    /// @notice The environment variable for the quorum denominator.
    string public constant ENV_QUORUM_DENOMINATOR = "QUORUM_DENOMINATOR";

    WavsServiceManager private serviceManager;
    uint256 private quorumNumerator;
    uint256 private quorumDenominator;

    /// @notice The setup function for the script.
    function setUp() public virtual {
        serviceManager = WavsServiceManager(vm.envAddress(ENV_SERVICE_MANAGER));
        quorumNumerator = vm.envUint(ENV_QUORUM_NUMERATOR);
        quorumDenominator = vm.envUint(ENV_QUORUM_DENOMINATOR);
    }

    /// @notice The run function for the script.
    function run() external {
        vm.startBroadcast();
        serviceManager.setQuorumThreshold(quorumNumerator, quorumDenominator);
        vm.stopBroadcast();
    }
}
