// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {IECDSAStakeRegistryTypes} from
    "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";

import {WavsMiddlewareDeploymentLib} from "./utils/WavsMiddlewareDeploymentLib.sol";
import {ReadCoreLib} from "./utils/ReadCoreLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";

/**
 * @title WavsMiddlewareDeployer
 * @author Lay3rLabs
 * @notice This script deploys the WavsMiddleware contracts.
 * @dev This script is used to deploy the WavsMiddleware contracts.
 */
contract WavsMiddlewareDeployer is Script, IECDSAStakeRegistryTypes {
    // using ReadCoreLib for *;
    using UpgradeableProxyLib for address;

    /// @notice The environment variable for the LST strategy address.
    string public constant ENV_LST_STRATEGY = "LST_STRATEGY_ADDRESS";
    /// @notice The environment variable for the metadata URI.
    string public constant ENV_METADATA_URI = "METADATA_URI";

    address private lstStrategyAddress;
    string private metadataUri;

    /// @notice The proxy admin address.
    address public proxyAdmin;
    /// @notice The deployment data.
    ReadCoreLib.DeploymentData public coreDeployment;
    /// @notice The WAVS middleware deployment data.
    WavsMiddlewareDeploymentLib.DeploymentData public wavsMiddlewareDeployment;
    Quorum internal quorum;

    /// @notice The error for the WAVS service manager address cannot be zero.
    error WavsMiddlewareDeployer__WavsServiceManagerAddressCannotBeZero();
    /// @notice The error for the stake registry address cannot be zero.
    error WavsMiddlewareDeployer__StakeRegistryAddressCannotBeZero();
    /// @notice The error for the strategy address cannot be zero.
    error WavsMiddlewareDeployer__StrategyAddressCannotBeZero();
    /// @notice The error for the proxy admin address cannot be zero.
    error WavsMiddlewareDeployer__ProxyAdminAddressCannotBeZero();
    /// @notice The error for the delegation manager address cannot be zero.
    error WavsMiddlewareDeployer__DelegationManagerAddressCannotBeZero();
    /// @notice The error for the AVS directory address cannot be zero.
    error WavsMiddlewareDeployer__AVSDirectoryAddressCannotBeZero();

    /// @notice The setup function for the script.
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

    /// @notice The run function for the script.
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

    /// @notice The verify deployment function.
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
