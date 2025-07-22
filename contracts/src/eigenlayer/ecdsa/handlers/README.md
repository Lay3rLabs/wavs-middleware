# ECDSA Service Handlers

This directory contains service handlers that need to be deployed with the middleware contracts and are used by external WAVS services that keep various pieces of state up to date. These services are critical to ensuring that changes in the operator set, quorum configuration, and stake registry are synchronized throughout the system.

Both of the mirror handlers are only necessary when data is being submitted to non-Ethereum chains, since they keep the mirror middleware in sync with the service deployment on Ethereum.

## WavsOperatorUpdateHandler

This handler updates operator weights in the stake registry to reflect changes in EigenLayer's operator set.

Used by `operator-updater` service.

## MirrorOperatorSyncHandler

This handler syncs operator info (registrations, signing keys, etc.) and stake thresholds from the service deployment on Ethereum to other chains (with the mirror middleware) that need to be able to verify operator signatures during WAVS submission.

Used by `multi-chain-operator-sync` service.

## MirrorQuorumSyncHandler

This handler syncs the quorum threshold from the service deployment on Ethereum to other chains (with the mirror middleware) that need to be able to verify operator signatures during WAVS submission.

Used by `multi-chain-quorum-sync` service.
