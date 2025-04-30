// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {PoAWavsServiceManager} from "../src/PoAWavsServiceManager.sol";
import {IWavsServiceManager} from "../src/interfaces/IWavsServiceManager.sol";
import "forge-std/console.sol";

/**
 * @title PoAWavsServiceManager Deployment Script
 * @notice Deploys a PoA Service Manager contract with configurable operators
 * @dev Usage:
 *    # Set operators using env variables (comma-separated)
 *    export OPERATORS="0x123,0x456,0x789"
 *    export REQUIRED_SIGNATURES=2
 *    export SERVICE_URI="https://example.com/service"
 *    forge script script/PoAWavsServiceManager.s.sol -vvv --broadcast
 *
 *    # Or use command line:
 *    forge script script/PoAWavsServiceManager.s.sol -vvv --sig "run(address[],uint256,string)" \
 *      "[(0x123,0x456,0x789)]" 2 "https://example.com/service" --broadcast
 */
contract DeployPoAWavsServiceManager is Script {
    function run() external {
        // Default deployment with empty operator set - add operators later
        address[] memory defaultOperators = new address[](0);
        run(defaultOperators, 0, "");
    }

    function run(
        address[] memory operators,
        uint256 requiredSignatures,
        string memory serviceUri
    ) public {
        // If operators array is empty, try to load from environment variables
        if (operators.length == 0) {
            operators = _getOperatorsFromEnv();

            // If still empty, warn and use a placeholder instead
            if (operators.length == 0) {
                console.log(
                    "Warning: No operators provided. Configure operators after deployment."
                );
                operators = new address[](1);
                operators[0] = address(this); // Use a placeholder so initialization doesn't fail
            }
        }

        // If requiredSignatures is 0, try to load from environment variables
        if (requiredSignatures == 0) {
            requiredSignatures = vm.envOr("REQUIRED_SIGNATURES", uint256(1));

            // Make sure the required signatures doesn't exceed available operators
            if (requiredSignatures > operators.length) {
                requiredSignatures = operators.length;
                console.log(
                    "Warning: Required signatures adjusted to match operator count:",
                    requiredSignatures
                );
            }
        }

        // If serviceUri is empty, try to load from environment variables
        if (bytes(serviceUri).length == 0) {
            serviceUri = vm.envOr("SERVICE_URI", string(""));
        }

        // Log deployment configuration
        console.log("Deploying PoAWavsServiceManager with:");
        console.log("Operators count:", operators.length);
        for (uint256 i = 0; i < operators.length; i++) {
            console.log("Operator", i, ":", operators[i]);
        }
        console.log("Required signatures:", requiredSignatures);
        if (bytes(serviceUri).length > 0) {
            console.log("Service URI:", serviceUri);
        }

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contract
        PoAWavsServiceManager poaManager = new PoAWavsServiceManager();

        // Initialize the contract
        poaManager.initialize(operators, requiredSignatures, deployerAddress);

        // Set service URI if provided
        if (bytes(serviceUri).length > 0) {
            poaManager.setServiceURI(serviceUri);
        }

        vm.stopBroadcast();

        console.log("PoAWavsServiceManager deployed at:", address(poaManager));
    }

    /**
     * @notice Parse operators from OPERATORS environment variable
     * @dev Format: comma-separated list of addresses "0x123,0x456,0x789"
     */
    function _getOperatorsFromEnv() internal view returns (address[] memory) {
        string memory operatorsEnv = vm.envOr("OPERATORS", string(""));

        if (bytes(operatorsEnv).length == 0) {
            return new address[](0);
        }

        // Count commas to determine array size
        uint256 count = 1;
        for (uint256 i = 0; i < bytes(operatorsEnv).length; i++) {
            if (bytes(operatorsEnv)[i] == ",") {
                count++;
            }
        }

        // Parse the comma-separated list
        address[] memory result = new address[](count);

        // Split string by commas
        uint256 operatorIndex = 0;
        uint256 lastIndex = 0;

        for (uint256 i = 0; i <= bytes(operatorsEnv).length; i++) {
            if (
                i == bytes(operatorsEnv).length || bytes(operatorsEnv)[i] == ","
            ) {
                // Extract substring and convert to address
                string memory addressStr = _substring(
                    operatorsEnv,
                    lastIndex,
                    i - lastIndex
                );
                result[operatorIndex] = vm.parseAddress(addressStr);
                operatorIndex++;
                lastIndex = i + 1;
            }
        }

        return result;
    }

    /**
     * @notice Extract a substring
     * @param str The source string
     * @param startIndex The starting index
     * @param length The substring length
     */
    function _substring(
        string memory str,
        uint256 startIndex,
        uint256 length
    ) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(length);

        for (uint256 i = 0; i < length; i++) {
            result[i] = strBytes[startIndex + i];
        }

        return string(result);
    }
}
