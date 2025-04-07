# Do not run this directly, this is meant to be imported by other scripts

export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

wait_for_ethereum() {
    echo "Waiting for Ethereum node to be ready..."
    while ! curl -s -X POST -H "Content-Type: application/json" \
                 --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
                 "$LOCAL_ETHEREUM_RPC_URL" > /dev/null
    do
        echo "$LOCAL_ETHEREUM_RPC_URL"
        sleep 1
    done
    echo "Ethereum node is ready!"
}

impersonate_account() {
    local account="$1"
    if [ "$DEPLOY_ENV" = "TESTNET" ]; then
        return 0
    fi
    cast rpc anvil_impersonateAccount $account -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        handle_error "Failed to impersonate account $account"
    fi
    cast rpc anvil_setBalance $account 0x10000000000000000000 -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        handle_error "Failed to set balance for account $account"
    fi
}

handle_error() {
    local message="$1"
    echo "Error: $message"
    exit 1
}

check_env_var() {
    local var_name="$1"
    local var_value="$2"
    if [ -z "$var_value" ]; then
        handle_error "$var_name is not set in the environment variables"
    fi
}

execute_transaction() {
    local description="$1"
    local command="$2"

    eval "$command"

    if [ $? -eq 0 ]; then
        echo "Successfully $description"
    else
        handle_error "Failed to $description"
    fi
}

stop_impersonating() {
    local account="$1"
    if [ "$DEPLOY_ENV" = "TESTNET" ]; then
        return 0
    fi
    cast rpc anvil_stopImpersonatingAccount "$account" -r "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to stop impersonating account $account"
        exit 1
    fi
}
