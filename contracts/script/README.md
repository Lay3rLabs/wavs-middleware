# WAVS Middleware Forge Scripts

This directory contains Forge scripts for deploying and managing WAVS (Wildly Applicable Validation Scheme) middleware contracts for EigenLayer.

## Scripts Overview

- `WavsDeployment.s.sol`: Main deployment script that handles the full deployment and configuration process

## WavsDeployment.s.sol

This script replaces the bash-based deployment process previously located in `docker/deploy.sh`. It provides a more maintainable and type-safe way to deploy and configure the WAVS middleware contracts.

### Features

- Deploys all middleware contracts
- Configures quorum settings with appropriate strategy weights
- Sets minimum weight requirements for operators
- Configures AVS registrar
- Updates metadata URI for the EigenLayer frontend
- Creates operator sets for meta-AVS functionality

### Environment Variables

| Variable               | Description                                            | Required    | Default |
| ---------------------- | ------------------------------------------------------ | ----------- | ------- |
| `FUNDED_KEY`           | Private key for deployment (must be funded)            | Yes         | -       |
| `LST_STRATEGY_ADDRESS` | Address of the LST strategy contract                   | Yes         | -       |
| `LST_CONTRACT_ADDRESS` | Address of the LST token contract                      | Yes         | -       |
| `DEPLOY_ENV`           | Deployment environment (`LOCAL` or `TESTNET`)          | Yes         | -       |
| `TESTNET_RPC_URL`      | RPC URL for testnet (required if `DEPLOY_ENV=TESTNET`) | Conditional | -       |
| `METADATA_URI`         | URI pointing to AVS metadata                           | Yes         | -       |

### Usage

To run the deployment script:

```bash
# First, set up the environment variables
cp docker/env.example docker/.env
# Edit docker/.env to add your configuration values

# Source the environment
source docker/.env

# For LOCAL environment
# 1. Start anvil in a separate terminal:
anvil --fork-url $RPC_URL --host 0.0.0.0 --port 8545

# 2. Run the deployment script:
forge script contracts/script/WavsDeployment.s.sol --rpc-url $LOCAL_ETHEREUM_RPC_URL --private-key $FUNDED_KEY --broadcast

# For TESTNET environment
forge script contracts/script/WavsDeployment.s.sol --rpc-url $TESTNET_RPC_URL --private-key $FUNDED_KEY --broadcast
```

## Deployment Process Flow

1. **Initial Setup**: Loads environment variables and validates required settings
2. **Deploy Middleware Contracts**:
   - Deploys proxy admin
   - Deploys stake registry, service manager, and AVS registrar contracts
   - Initializes contracts with proper configuration
   - Writes deployment addresses to JSON file
3. **Configure Contracts**:
   - Updates quorum config with strategy weights
   - Sets minimum weight for operators
   - Configures AVS registrar
   - Updates metadata URL for EigenLayer frontend
   - Creates operator sets for meta-AVS functionality

## Output

Upon successful execution, the script will:

1. Print the deployed contract addresses to the console
2. Write deployment information to `deployments/wavs-middleware/{chainId}.json`
3. Copy the deployment information to `~/.nodes/avs_deploy.json` for use by other tools

## Troubleshooting

### Common Issues

- **Transaction Failures**: Ensure your private key is funded with enough ETH to cover gas costs
- **Missing Environment Variables**: Check that all required environment variables are set
- **Contract Verification Errors**: Ensure all contract dependencies are available in the correct versions

### Logs

The script outputs detailed logs to the console, showing each step of the deployment process. If an error occurs, check the console output for specific error messages.
