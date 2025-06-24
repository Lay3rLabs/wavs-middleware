## Prerequisites

- Docker and Docker Compose
- Foundry (Forge and Cast) for local development and testing

## Testing

To run the test suite, make sure you have [Foundry](https://book.getfoundry.sh/) installed. Then run:

```bash
# Run all tests
cd contracts
forge test -C ./eigenlayer -vvv

# Run a specific test function
forge test -C ./eigenlayer --match-test test_pause -vvv
```

# Docker Quick start

## Build

First, ensure you have all submodules:

```bash
git submodule update --init --recursive
```

Then, build the image:

```bash
docker build -t wavs-middleware .
```

## Setup

Prepare the env file:

```bash
cp docker/env.example docker/.env
# edit the RPC_URL for a paid testnet rpc endpoint, add funded key, and TESTNET_RPC_URL
```

## Testnet Fork

Start anvil in one terminal:

```bash
source docker/.env
anvil --fork-url $RPC_URL --host 0.0.0.0 --port 8545
```

## Deploy

**Run all the following scripts in the `docker/` directory.**

```bash
cd docker/
```

Deploy:

```bash
docker run --rm --network host --env-file .env -v ./.nodes:/root/.nodes wavs-middleware deploy
```

Set Service URI:

```bash
SERVICE_URI="https://ipfs.url/for-custom-service.json"

docker run --rm --network host --env-file .env -v ./.nodes:/root/.nodes wavs-middleware set_service_uri "$SERVICE_URI"
```

Register:

```bash
# Generate a new private key for the operator (needs ETH for transactions)
OPERATOR_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
OPERATOR_ADDRESS=$(cast wallet addr --private-key "$OPERATOR_KEY")
echo "Operator address: $OPERATOR_ADDRESS"

export WAVS_SERVICE_MANAGER_ADDRESS=$(jq -r '.addresses.WavsServiceManager' .nodes/avs_deploy.json)

# Generate or use an existing AVS signing key address
# Option 1: Generate a new AVS signing key
AVS_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
AVS_SIGNING_ADDRESS=$(cast wallet addr --private-key "$AVS_KEY")
echo "AVS signing address: $AVS_SIGNING_ADDRESS"

# Option 2: Use an existing AVS signing address from your AVS node
# AVS_SIGNING_ADDRESS="0x..." # Address of the key that will sign for the AVS

# Register the operator using the operator key and AVS signing address
docker run --rm --network host --env-file .env \
   -e WAVS_SERVICE_MANAGER_ADDRESS=${WAVS_SERVICE_MANAGER_ADDRESS} \
   wavs-middleware register "$OPERATOR_KEY" "$AVS_SIGNING_ADDRESS" "1000000000000000"
```

List Operators:

```bash
# View stake registry status, including registered operators and their weights
docker run --rm --network host  --env-file .env \
   -e WAVS_SERVICE_MANAGER_ADDRESS=${WAVS_SERVICE_MANAGER_ADDRESS} \
   wavs-middleware list_operators
```

Pause Registration:

```bash
docker run --rm --network host --env-file .env -v ./.nodes:/root/.nodes wavs-middleware pause
```

Unpause Registration:

```bash
docker run --rm --network host --env-file .env -v ./.nodes:/root/.nodes wavs-middleware unpause
```

Delegation to Operator:

```bash
# Generate a new private key for the staker (needs ETH for transactions)
STAKER_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
STAKER_ADDRESS=$(cast wallet addr --private-key "$STAKER_KEY")
echo "Staker address: $STAKER_ADDRESS"

export DELEGATION_MANAGER_ADDRESS=0xA44151489861Fe9e3055d95adC98FbD462B948e7

docker run --rm --network host  --env-file .env -v ./.nodes:/root/.nodes \
   -e STAKER_KEY=${STAKER_KEY} \
   -e OPERATOR_ADDRESS=${OPERATOR_ADDRESS} \
   -e WAVS_SERVICE_MANAGER_ADDRESS=${WAVS_SERVICE_MANAGER_ADDRESS} \
   -e DELEGATION_MANAGER_ADDRESS=${DELEGATION_MANAGER_ADDRESS} \
   -e DELEGATION_APPROVER_PRIVATE_KEY=${OPERATOR_KEY} \
   -e DELEGATION_APPROVER_SALT=0x0000000000000000000000000000000000000000000000000000000000000000 \
   -e DELEGATION_DURATION=86400 \
   wavs-middleware delegate_to_operator
```

## Deploying Mirror

Run a second anvil at port 8546 with no eigenlayer deployed (can be not fork)

```bash
anvil --host 0.0.0.0 --port 8546
```

Deploy mirror contracts to match first anvil

```bash
export WAVS_SERVICE_MANAGER_ADDRESS=$(jq -r '.addresses.WavsServiceManager' .nodes/avs_deploy.json)

export SOURCE_RPC_URL=http://localhost:8545
export MIRROR_RPC_URL=http://localhost:8546

# Register the operator using the operator key and AVS signing address
docker run --rm --network host --env-file .env -v ./.nodes:/root/.nodes \
   -e WAVS_SERVICE_MANAGER_ADDRESS=${WAVS_SERVICE_MANAGER_ADDRESS} \
   -e SOURCE_RPC_URL=${SOURCE_RPC_URL} \
   -e MIRROR_RPC_URL=${MIRROR_RPC_URL} \
   wavs-middleware -m mirror deploy
```

List Mirror Operators:

```bash
source .env
export SOURCE_SERVICE_MANAGER_ADDRESS=$(jq -r '.addresses.WavsServiceManager' ".nodes/avs_deploy.json")
export MIRROR_SERVICE_MANAGER_ADDRESS=$(jq -r '.addresses.WavsServiceManager' ".nodes/mirror-$MIRROR_CHAIN_ID.json")

export SOURCE_RPC_URL=http://localhost:8545
export MIRROR_RPC_URL=http://localhost:8546

# View stake registry status, including registered operators and their weights
docker run --rm --network host --env-file .env -v ./.nodes:/root/.nodes \
   -e SOURCE_SERVICE_MANAGER_ADDRESS=${SOURCE_SERVICE_MANAGER_ADDRESS} \
   -e MIRROR_SERVICE_MANAGER_ADDRESS=${MIRROR_SERVICE_MANAGER_ADDRESS} \
   -e SOURCE_RPC_URL=${SOURCE_RPC_URL} \
   -e MIRROR_RPC_URL=${MIRROR_RPC_URL} \
   wavs-middleware -m mirror list_operators
```

## Mock Deployment

This deployment process is for local testing and development. It deploys a "mock" version of the WAVS middleware contracts by using the mock stage of the mirror deployment scripts. This allows for rapid testing without needing to interact with a live EigenLayer environment.

### 1. Create a Configuration File

Create a `mock-config.json` file on your local machine. This file defines the initial operators, their signing keys, weights, and the threshold for the stake registry.

```json
{
  "operators": [
    "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf",
    "0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF",
    "0x6813Eb9362372EEF6200f3b1dbC3f819671cBA69",
    "0x1efF47bc3a10a45D4B230B5d10E37751FE6AA718",
    "0xe1AB8145F7E55DC933d51a18c793F901A3A0b276"
  ],
  "quorumDenominator": 3,
  "quorumNumerator": 2,
  "signingKeys": [
    "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf",
    "0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF",
    "0x6813Eb9362372EEF6200f3b1dbC3f819671cBA69",
    "0x1efF47bc3a10a45D4B230B5d10E37751FE6AA718",
    "0xe1AB8145F7E55DC933d51a18c793F901A3A0b276"
  ],
  "threshold": 12345,
  "weights": [10000, 10000, 10000, 10000, 10000]
}
```

### 2. Run a Local Blockchain

```bash
anvil --host 0.0.0.0 --port 8546
```

### 3. Deploy the Mock Contracts

```bash
# Set the path to your local config file
export LOCAL_CONFIG_PATH=$(pwd)/mock-config.json

# Set the RPC URL for the local blockchain
export MOCK_RPC_URL=http://localhost:8546

# Generate a new private key for the staker (needs ETH for transactions)
MOCK_DEPLOYER_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
MOCK_DEPLOYER_ADDRESS=$(cast wallet addr --private-key "$MOCK_DEPLOYER_KEY")
echo "Mock deployer address: $MOCK_DEPLOYER_ADDRESS"

docker run --rm --network host --env-file .env -v ./.nodes:/root/.nodes \
   -v $LOCAL_CONFIG_PATH:/wavs/contracts/deployments/wavs-mock-config.json \
   -e MOCK_DEPLOYER_KEY=${MOCK_DEPLOYER_KEY} \
   -e MOCK_RPC_URL=${MOCK_RPC_URL} \
   wavs-middleware -m mock deploy
```

## Deploy Testnet

Same as the local deploy, but add `TESTNET_RPC_URL` to the .env and change `DEPLOY_ENV` to `"TESTNET"` and make sure the `FUNDED_KEY` is actually funded on testnet

## References

- [EigenLayer Documentation](https://docs.eigenlayer.xyz/)
- [Hello World AVS Repository](https://github.com/Layr-Labs/hello-world-avs)

## Deployment Process Flow

```mermaid
sequenceDiagram
    autonumber
    participant Env as Environment
    participant Deploy as Deploy Script
    participant Service as Service U
    participant Register as Register Operator
    participant Contracts as Contracts

    Env->>Env: Load Environment Variables
    Env->>Env: Set LOCAL_ETHEREUM_RPC_URL
    Env->>Env: Check Required Variables

    Deploy->>Contracts: Deploy Middleware Contracts
    Deploy->>Deploy: Read Contract Addresses
    Deploy->>Contracts: Update Quorum Config
    Deploy->>Contracts: Update Minimum Weight
    Deploy->>Contracts: Update AVS Registrar
    Deploy->>Contracts: Update Metadata URL
    Deploy->>Contracts: Create Operator Sets

    Service->>Service: Read Deployer Key
    Service->>Service: Get Service Manager Address
    Service->>Service: Get Owner Address
    Service->>Contracts: Impersonate Owner
    Service->>Contracts: Set Service URI
    Service->>Contracts: Stop Impersonating

    Register->>Register: Read Operator Key and AVS Signing Address
    Register->>Register: Setup Operator
    Register->>Register: Fund Operator Account
    Register->>Contracts: Mint LST Tokens
    Register->>Contracts: Approve LST Tokens
    Register->>Contracts: Deposit into Strategy
    Register->>Contracts: Register as Operator
    Register->>Contracts: Register for Operator Sets
    Register->>Contracts: Get Stake Registry Address
    Register->>Contracts: Get Service Manager Address
    Register->>Contracts: Get AVS Directory Address
    Register->>Register: Generate Random Salt
    Register->>Register: Calculate Expiry
    Register->>Register: Calculate Digest Hash
    Register->>Register: Sign Digest Hash with Operator Key
    Register->>Contracts: Register with Signature using AVS Signing Address
```

## Detailed Process Explanation

### Initial Setup

- Load environment variables from `.env` file
- Set `LOCAL_ETHEREUM_RPC_URL` based on environment (TESTNET or LOCAL)
- Check for required environment variables

### Deploy Process (deploy.sh)

1. Deploy middleware contracts using Forge script
2. Read contract addresses from deployment JSON
3. Update quorum config with strategy weights
4. Set minimum weight for operators
5. Configure AVS registrar
6. Update metadata URL for EigenLayer frontend
7. Create operator sets for meta-AVS functionality

### Set Service URI (set_service_uri.sh)

1. Read deployer private key from file
2. Get service manager address from deployment JSON
3. Get owner address from service manager contract
4. Impersonate owner account (LOCAL only)
5. Set service URI on service manager contract
6. Stop impersonating owner account

### Register Operator (register.sh)

1. Read operator private key and AVS signing address from command line
2. Setup operator with initial configuration
3. Fund operator account with ETH
4. Mint LST tokens for operator
5. Approve LST tokens for strategy manager
6. Deposit LST tokens into strategy
7. Register as operator with delegation manager
8. Register for operator sets with allocation manager
9. Register with AVS using signature:
   - Get stake registry address
   - Get service manager address
   - Get AVS directory address
   - Generate random salt
   - Calculate expiry time
   - Calculate digest hash
   - Sign digest hash with operator's private key
   - Register with signature on stake registry, using the AVS signing address as the signing key

### Helper Functions (helpers.sh)

- `wait_for_ethereum`: Check if Ethereum node is ready
- `impersonate_account`: Impersonate an account (LOCAL only)
- `execute_transaction`: Run a transaction and handle errors
- `stop_impersonating`: Stop impersonating an account (LOCAL only)

### Instructions on getting Holesky ETH

To get Holesky ETH for running on testnet:

1. PoW Mining Faucet:

   - Go to https://holesky-faucet.pk910.de/
   - Connect your wallet
   - Mine blocks in your browser to earn ETH
   - Rewards based on mining time/hashrate
   - No external requirements

2. Alchemy Faucet (Alternative):
   - Visit https://www.alchemy.com/faucets/holesky
   - Requires mainnet ETH balance to use
   - Connect wallet and verify ownership
   - Request funds (limits apply)
