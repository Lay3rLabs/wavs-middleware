// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {WavsMiddlewareDeploymentLib} from "./utils/WavsMiddlewareDeplomentLib.sol";
import {ReadCoreLib} from "./utils/ReadCoreLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";
import {
    IECDSAStakeRegistryTypes,
    IStrategy
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";


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

    address proxyAdmin;
    ReadCoreLib.DeploymentData coreDeployment;
    WavsMiddlewareDeploymentLib.DeploymentData wavsMiddlewareDeployment;
    Quorum internal quorum;

    function setUp() public virtual {
        coreDeployment = ReadCoreLib.readDeploymentJson("deployments/eigenlayer-core/", block.chainid);

        // Get the configuration from environment
        lstStrategyAddress = vm.envAddress(ENV_LST_STRATEGY);
        metadataUri = vm.envString(ENV_METADATA_URI);

        // Local Deployment assumes testnet strategies, for documentation on strategies on different chains see:
        // https://github.com/layr-labs/eigenlayer-contracts In the README.md
        // 0x7d704507b76571a51d9cae8addabbfd0ba0e63d3 is sETH on Holesky
        quorum = WavsMiddlewareDeploymentLib.readQuorumConfig("deployments/strategies/", block.chainid); 
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
        WavsMiddlewareDeploymentLib.configureContracts(wavsMiddlewareDeployment, metadataUri, minimumWeight);

        vm.stopBroadcast();

        verifyDeployment();
        WavsMiddlewareDeploymentLib.writeDeploymentJson(wavsMiddlewareDeployment);
    }

    function verifyDeployment() internal view {
        require(
            wavsMiddlewareDeployment.stakeRegistry != address(0), "StakeRegistry address cannot be zero"
        );
        require(
            wavsMiddlewareDeployment.WavsServiceManager != address(0),
            "WavsServiceManager address cannot be zero"
        );
        require(wavsMiddlewareDeployment.strategy != address(0), "Strategy address cannot be zero");
        require(proxyAdmin != address(0), "ProxyAdmin address cannot be zero");
        require(
            coreDeployment.delegationManager != address(0),
            "DelegationManager address cannot be zero"
        );
        require(coreDeployment.avsDirectory != address(0), "AVSDirectory address cannot be zero");
    }
}
