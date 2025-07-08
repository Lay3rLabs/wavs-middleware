// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {IECDSAStakeRegistryTypes} from
    "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";

import {WavsMiddlewareDeploymentLib} from "./utils/WavsMiddlewareDeploymentLib.sol";
import {ReadCoreLib} from "./utils/ReadCoreLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";

contract WavsMiddlewareDeployer is Script, IECDSAStakeRegistryTypes {
    // using ReadCoreLib for *;
    using UpgradeableProxyLib for address;

    // Environment variables for deployContracts
    string public constant ENV_LST_STRATEGY = "LST_STRATEGY_ADDRESS";
    // Environment variables for configureContracts
    string public constant ENV_METADATA_URI = "METADATA_URI";

    // Deployment configuration
    address private lstStrategyAddress;
    string private metadataUri;

    address public proxyAdmin;
    ReadCoreLib.DeploymentData public coreDeployment;
    WavsMiddlewareDeploymentLib.DeploymentData public wavsMiddlewareDeployment;
    Quorum internal quorum;

    error WavsMiddlewareDeployer__WavsServiceManagerAddressCannotBeZero();
    error WavsMiddlewareDeployer__StakeRegistryAddressCannotBeZero();
    error WavsMiddlewareDeployer__StrategyAddressCannotBeZero();
    error WavsMiddlewareDeployer__ProxyAdminAddressCannotBeZero();
    error WavsMiddlewareDeployer__DelegationManagerAddressCannotBeZero();
    error WavsMiddlewareDeployer__AVSDirectoryAddressCannotBeZero();

    function setUp() public virtual {
        coreDeployment =
            ReadCoreLib.readDeploymentJson("deployments/eigenlayer-core/", block.chainid);

        // Get the configuration from environment
        lstStrategyAddress = vm.envAddress(ENV_LST_STRATEGY);
        metadataUri = vm.envString(ENV_METADATA_URI);

        // Local Deployment assumes testnet strategies, for documentation on strategies on different chains see:
        // https://github.com/layr-labs/eigenlayer-contracts In the README.md
        // 0x7d704507b76571a51d9cae8addabbfd0ba0e63d3 is sETH on Holesky
        quorum =
            WavsMiddlewareDeploymentLib.readQuorumConfig("deployments/strategies/", block.chainid);
    }

    function run() external {
        vm.startBroadcast();
        proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        // first deploy (from eigenlayer)
        wavsMiddlewareDeployment =
            WavsMiddlewareDeploymentLib.deployContracts(proxyAdmin, coreDeployment, quorum);

        // WAVS configuration
        uint256 minimumWeight = 100;
        wavsMiddlewareDeployment.strategy = lstStrategyAddress;
        WavsMiddlewareDeploymentLib.configureContracts(
            wavsMiddlewareDeployment, metadataUri, minimumWeight
        );

        vm.stopBroadcast();

        verifyDeployment();
        WavsMiddlewareDeploymentLib.writeDeploymentJson(wavsMiddlewareDeployment);
    }

    function verifyDeployment() internal view {
        if (wavsMiddlewareDeployment.stakeRegistry == address(0)) {
            revert WavsMiddlewareDeployer__StakeRegistryAddressCannotBeZero();
        }
        if (wavsMiddlewareDeployment.wavsServiceManager == address(0)) {
            revert WavsMiddlewareDeployer__WavsServiceManagerAddressCannotBeZero();
        }
        if (wavsMiddlewareDeployment.strategy == address(0)) {
            revert WavsMiddlewareDeployer__StrategyAddressCannotBeZero();
        }
        if (proxyAdmin == address(0)) {
            revert WavsMiddlewareDeployer__ProxyAdminAddressCannotBeZero();
        }
        if (coreDeployment.delegationManager == address(0)) {
            revert WavsMiddlewareDeployer__DelegationManagerAddressCannotBeZero();
        }
        if (coreDeployment.avsDirectory == address(0)) {
            revert WavsMiddlewareDeployer__AVSDirectoryAddressCannotBeZero();
        }
    }
}
