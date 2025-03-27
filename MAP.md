# Deployment Contract Map

`wavs-el-env` has `start.sh` that deploys the wavs contracts.
This requires foundry and calls into `cd contracts && forge script script/LayerMiddlewareDeployer.s.sol --rpc-url $LOCAL_ETHEREUM_RPC_URL --broadcast`

This is now in the current repo, [`LayerMiddlewareDeployer.s.sol`](./contracts/script/LayerMiddlewareDeployer.s.sol)

That then calls into [`LayerMiddlewareDeployerLib.sol`](./contracts/script/utils/LayerMiddlewareDeplomentLib.sol)

## Deployment Code

```solidity
    function deployContracts(
        address proxyAdmin,
        CoreDeploymentLib.DeploymentData memory core,
        IECDSAStakeRegistryTypes.Quorum memory quorum
    ) internal returns (DeploymentData memory) {
        DeploymentData memory result;

        // First, deploy upgradeable proxy contracts that will point to the implementations.
        result.WavsServiceManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.stakeRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        // Deploy the implementation contracts, using the proxy contracts as inputs
        address stakeRegistryImpl =
            address(new ECDSAStakeRegistry(IDelegationManager(core.delegationManager)));
        address WavsServiceManagerImpl = address(
            new WavsServiceManager(
                core.avsDirectory,
                result.stakeRegistry,
                core.rewardsCoordinator,
                core.delegationManager,
                core.allocationManager
            )
        );
        // Upgrade contracts
        bytes memory stakeRegistryUpgradeCall = abi.encodeCall(
            ECDSAStakeRegistry.initialize, (result.WavsServiceManager, 0, quorum)
        );
        bytes memory WavsServiceManagerUpgradeCall = abi.encodeCall(
            WavsServiceManager.initialize, (msg.sender, msg.sender)
        );
        UpgradeableProxyLib.upgradeAndCall(result.stakeRegistry, stakeRegistryImpl, stakeRegistryUpgradeCall);
        UpgradeableProxyLib.upgradeAndCall(result.WavsServiceManager, WavsServiceManagerImpl, WavsServiceManagerUpgradeCall);

        // TODO: This is incredibly stupid, 
        // when we implement out own stake registry, pass owner as an argument
        bytes memory stakeRegistryOwnerUpgradeCall = abi.encodeCall(
            Ownable.transferOwnership, (msg.sender)
        );
        UpgradeableProxyLib.upgradeAndCall(result.stakeRegistry, stakeRegistryImpl, stakeRegistryOwnerUpgradeCall);

        // Dummy AVSRegistrar deployment for now
        address avsRegistrar = address(new WavsAVSRegistrar());
        result.avsRegistrar = avsRegistrar;

        result.metadataURI = core.metadataURI;
        return result;
    }
```

## Contract Sources

* `UpgradeableProxyLib` - ./UpgradeableProxyLib.sol
* `ECDSAStakeRegistry` - @eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol
* `IDelegationManager` - @eigenlayer/contracts/interfaces/IDelegationManager.sol
* `WavsAVSRegistrar` - ../../src/WavsAVSRegistrar.sol
  * `IAVSRegistrar` - @eigenlayer/contracts/interfaces/IAVSRegistrar.sol
* `WavsServiceManager` - ../../src/WavsServiceManager.sol
  * LOTS from eigenlayer, eigenlayer-middleware, openzeppelin

