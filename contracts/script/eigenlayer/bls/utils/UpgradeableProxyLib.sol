// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Vm} from "forge-std/Vm.sol";
import {EmptyContract} from "@eigenlayer/test/mocks/EmptyContract.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title UpgradeableProxyLib
 * @author Lay3rLabs
 * @notice This library contains functions for upgrading the proxy contracts.
 * @dev This library is used to upgrade the proxy contracts.
 */
library UpgradeableProxyLib {
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /**
     * @notice The deploy proxy admin function.
     * @return proxyAdmin The proxy admin address.
     */
    function deployProxyAdmin() internal returns (address) {
        return address(new ProxyAdmin());
    }

    /**
     * @notice The set up empty proxy function.
     * @param admin The admin address.
     * @return proxy The proxy address.
     */
    function setUpEmptyProxy(
        address admin
    ) internal returns (address) {
        address emptyContract = address(new EmptyContract());
        return address(new TransparentUpgradeableProxy(emptyContract, admin, ""));
    }

    /**
     * @notice The upgrade function.
     * @param proxy The proxy address.
     * @param impl The implementation address.
     */
    function upgrade(address proxy, address impl) internal {
        ProxyAdmin admin = getProxyAdmin(proxy);
        admin.upgrade(ITransparentUpgradeableProxy(payable(proxy)), impl);
    }

    /**
     * @notice The upgrade and call function.
     * @param proxy The proxy address.
     * @param impl The implementation address.
     * @param initData The initialization data.
     */
    function upgradeAndCall(address proxy, address impl, bytes memory initData) internal {
        ProxyAdmin admin = getProxyAdmin(proxy);
        admin.upgradeAndCall(ITransparentUpgradeableProxy(payable(proxy)), impl, initData);
    }

    /**
     * @notice The get implementation function.
     * @param proxy The proxy address.
     * @return implementation The implementation address.
     */
    function getImplementation(
        address proxy
    ) internal view returns (address) {
        bytes32 value = VM.load(proxy, IMPLEMENTATION_SLOT);
        return address(uint160(uint256(value)));
    }

    /**
     * @notice The get proxy admin function.
     * @param proxy The proxy address.
     * @return proxyAdmin The proxy admin address.
     */
    function getProxyAdmin(
        address proxy
    ) internal view returns (ProxyAdmin) {
        bytes32 value = VM.load(proxy, ADMIN_SLOT);
        return ProxyAdmin(address(uint160(uint256(value))));
    }
}
