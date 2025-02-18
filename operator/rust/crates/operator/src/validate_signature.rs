#![allow(missing_docs)]
use alloy::dyn_abi::DynSolValue;
use alloy::{
    primitives::{eip191_hash_message, keccak256, U256},
    providers::Provider,
    signers::{local::PrivateKeySigner, SignerSync},
    sol_types::SolValue,
};
use dotenv::dotenv;

use eigen_logging::{get_logger, init_logger, log_level::LogLevel};
use eigen_utils::{get_provider, get_signer};
use eyre::Result;
use hello_world_utils::offchainmessageconsumer::ILayerSDK::Task;
use hello_world_utils::offchainmessageconsumer::OffchainMessageConsumer;
use hello_world_utils::parse_offchain_message_consumer_address;
use once_cell::sync::Lazy;
use std::{env, str::FromStr};

pub const fn get_rpc_url() -> String {
    match env::var("DEPLOY_ENV") {
        Ok(env) if env == "LOCAL" => {
            // Always use the ethereum URL for local
            "http://ethereum:8545".to_string()
        }
        Ok(env) if env == "TESTNET" => {
            // Only use TESTNET_RPC_URL if explicitly in TESTNET mode
            match env::var("TESTNET_RPC_URL") {
                Ok(url) => url,
                Err(_) => {
                    eprintln!("Warning: TESTNET_RPC_URL is not set; falling back to http://ethereum:8545");
                    "http://ethereum:8545".to_string()
                }
            }
        }
        // Fallback if DEPLOY_ENV is neither LOCAL nor TESTNET
        _ => {
            eprintln!("Warning: DEPLOY_ENV is not set or invalid; falling back to http://ethereum:8545");
            "http://ethereum:8545".to_string()
        }
    }
}
pub const ANVIL_RPC_URL: &str = get_rpc_url();
fn read_private_keys() -> Result<Vec<String>> {
    let home = env::var("HOME").expect("HOME environment variable not set");
    let mut keys = Vec::new();

    let amt_keys: isize = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "3".to_string())
        .parse::<isize>()
        .unwrap();

    for i in 1..=amt_keys {
        let key_path = format!("{}/.nodes/operator{}", home, i);
        let key = std::fs::read_to_string(key_path)?;
        // Extract the key from environment variable format
        let clean_key = key
            .lines()
            .find(|line| line.contains("PRIVATE_KEY"))
            .and_then(|line| line.split('=').nth(1))
            .ok_or_else(|| eyre::eyre!("No private key found in operator{}", i))?
            .trim()
            .trim_start_matches("0x")
            .to_string();

        // Ensure the key is properly formatted with 0x prefix
        let formatted_key = if clean_key.len() == 64 {
            format!("0x{}", clean_key)
        } else {
            return Err(eyre::eyre!(
                "Invalid key length {} (expected 64) in operator{}. Original line: {}",
                clean_key.len(),
                i,
                key.trim().len()
            ));
        };

        keys.push(formatted_key);
    }
    Ok(keys)
}
static KEYS: Lazy<Vec<String>> =
    Lazy::new(|| read_private_keys().expect("failed to read private keys"));

async fn validate_signature(message: String) -> Result<()> {
    let pr = get_signer(&KEYS[0], ANVIL_RPC_URL);

    // First create and sort operators
    let mut operator_addresses = Vec::new();
    let mut key_map = std::collections::HashMap::new();

    // Create a mapping of addresses to keys and collect addresses
    for key in KEYS.iter() {
        let signer = PrivateKeySigner::from_str(key)?;
        let address = signer.address();
        operator_addresses.push(address);
        key_map.insert(address, key.to_string());
    }

    // Sort operator addresses
    operator_addresses.sort();

    // Create sorted DynSolValue vectors
    let mut operators: Vec<DynSolValue> = Vec::new();
    let mut signatures: Vec<DynSolValue> = Vec::new();

    let m_hash = eip191_hash_message(keccak256(message.abi_encode_packed()));

    // Create signatures in the same order as sorted operators
    for address in operator_addresses {
        operators.push(DynSolValue::Address(address));

        // Get corresponding key and create signature
        let key = key_map.get(&address).expect("Key must exist for address");
        let signer = PrivateKeySigner::from_str(key)?;
        signatures.push(DynSolValue::Bytes(signer.sign_hash_sync(&m_hash)?.into()));
    }

    let current_block = U256::from(get_provider(ANVIL_RPC_URL).get_block_number().await?);
    let signature_data = DynSolValue::Tuple(vec![
        DynSolValue::Array(operators),
        DynSolValue::Array(signatures),
        DynSolValue::Uint(current_block, 32),
    ])
    .abi_encode_params();
    let task = Task {
        dataHash: m_hash,
        signatureData: signature_data.into(),
    };
    let offchain_message_consumer_address = parse_offchain_message_consumer_address(
        "contracts/deployments/layer-middleware/17000.json",
    )?;
    let offchain_message_consumer =
        OffchainMessageConsumer::new(offchain_message_consumer_address, &pr);
    let tx = offchain_message_consumer
        .validateOffchainMessage(task)
        .gas(500000)
        .send()
        .await?
        .get_receipt()
        .await?
        .transaction_hash;
    get_logger().info(
        &format!("Signature verification completed with tx hash {}", tx),
        "",
    );
    Ok(())
}

#[tokio::main]
pub async fn main() {
    dotenv().ok();
    init_logger(LogLevel::Info);
    if let Err(e) = validate_signature("Hello, World!".to_string()).await {
        eprintln!("Failed to validate signature: {:?}", e);
        return;
    }
}
