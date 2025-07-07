// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";

import {WavsServiceManager} from "../src/WavsServiceManager.sol";

contract WavsUpdateQuorum is Script {
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";
    string public constant ENV_QUORUM_NUMERATOR = "QUORUM_NUMERATOR";
    string public constant ENV_QUORUM_DENOMINATOR = "QUORUM_DENOMINATOR";

    // configuration
    WavsServiceManager private serviceManager;
    uint256 private quorumNumerator;
    uint256 private quorumDenominator;

    function setUp() public virtual {
        serviceManager = WavsServiceManager(vm.envAddress(ENV_SERVICE_MANAGER));
        quorumNumerator = vm.envUint(ENV_QUORUM_NUMERATOR);
        quorumDenominator = vm.envUint(ENV_QUORUM_DENOMINATOR);
    }

    function run() external {
        vm.startBroadcast();
        serviceManager.setQuorumThreshold(quorumNumerator, quorumDenominator);
        vm.stopBroadcast();
    }
}
