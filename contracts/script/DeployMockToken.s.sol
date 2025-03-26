// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Script, console } from "forge-std/Script.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        address _initialHolder,
        uint256 _initialSupply
    ) ERC20(_name, _symbol) {
        _mint(_initialHolder, _initialSupply);
    }
}

contract DeployMockTokenScript is Script {
    function run(address recipient, uint256 amount) external {
        vm.startBroadcast();

        MockToken mockToken = new MockToken(
            "Mock Token",
            "MKT",
            recipient,
            amount
        );

        vm.stopBroadcast();
        string memory json = vm.serializeAddress("deployment", "MockToken", address(mockToken));
        vm.writeJson(json, string.concat("./deployments/wavs-middleware/mockToken", vm.toString(block.chainid), ".json"));
    }
}
