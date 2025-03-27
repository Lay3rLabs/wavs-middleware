#![allow(missing_docs)]
use alloy::{
    primitives::{Address, FixedBytes, U256},
    signers::{local::PrivateKeySigner, SignerSync},
};
use chrono::Utc;
use dotenv::dotenv;
use eigen_client_elcontracts::reader::ELChainReader;
use eigen_logging::{get_logger, init_logger, log_level::LogLevel};
use eigen_utils::get_signer;
use hello_world_utils::ecdsastakeregistry::ECDSAStakeRegistry;
use hello_world_utils::{
    ecdsastakeregistry::ISignatureUtils::SignatureWithSaltAndExpiry,
    EigenLayerData,
};
use hello_world_utils::{parse_layer_service_manager, parse_stake_registry_address_layer};

use once_cell::sync::Lazy;
use rand::RngCore;
use std::{env, str::FromStr};

pub const fn get_rpc_url() -> &'static str {
    match option_env!("TESTNET_RPC_URL") {
        Some(url) => url,
        None => "http://localhost:8545",
    }
}
pub const ANVIL_RPC_URL: &str = get_rpc_url();
static KEY: Lazy<String> =
    Lazy::new(|| env::var("PRIVATE_KEY").expect("failed to retrieve private key"));

async fn register_operator() -> eyre::Result<()> {
    let pr = get_signer(&KEY.clone(), ANVIL_RPC_URL);
    let signer = PrivateKeySigner::from_str(&KEY.clone())?;

    let default_slasher = Address::ZERO;

    let data = std::fs::read_to_string("/wavs/contracts/deployments/core/17000.json")?;
    let el_parsed: EigenLayerData = serde_json::from_str(&data)?;
    let delegation_manager_address: Address = el_parsed.addresses.delegation.parse()?;
    let avs_directory_address: Address = el_parsed.addresses.avs_directory.parse()?;

    let elcontracts_reader_instance = ELChainReader::new(
        get_logger().clone(),
        default_slasher,
        delegation_manager_address,
        avs_directory_address,
        ANVIL_RPC_URL.to_string(),
    );

    let is_registered = elcontracts_reader_instance
        .is_operator_registered(signer.address())
        .await
        .unwrap();
    get_logger().info(&format!("is registered {}", is_registered), &"");

    let mut salt = [0u8; 32];
    rand::rngs::OsRng.fill_bytes(&mut salt);

    let salt = FixedBytes::from_slice(&salt);
    let now = Utc::now().timestamp();
    let expiry: U256 = U256::from(now + 3600);
    let data = std::fs::read_to_string("/wavs/contracts/deployments/wavs-middleware/17000.json")?;
    get_logger().info(&format!("wavs-middleware deployment data: {}", data), &"");
    // Use the correct parse function for LayerMiddleware JSON
    let layer_service_manager_address = parse_layer_service_manager(
        "/wavs/contracts/deployments/wavs-middleware/17000.json",
    )?;
    get_logger().info(&format!("layer_service_manager_address: {}", layer_service_manager_address), &"");
    let digest_hash = elcontracts_reader_instance
        .calculate_operator_avs_registration_digest_hash(
            signer.address(),
            layer_service_manager_address,
            salt,
            expiry,
        )
        .await?;
    get_logger().info(&format!("digest_hash: {}", digest_hash), &"");

    let signature = signer.sign_hash_sync(&digest_hash)?;
    let operator_signature = SignatureWithSaltAndExpiry {
        signature: signature.as_bytes().into(),
        salt,
        expiry: expiry,
    };

    // Use the LayerMiddleware parsing function for stake registry
    let stake_registry_address = parse_stake_registry_address_layer(
        "/wavs/contracts/deployments/wavs-middleware/17000.json",
    )?;
    let contract_ecdsa_stake_registry =
        ECDSAStakeRegistry::new(stake_registry_address, &pr);
    let registeroperator_details_call = contract_ecdsa_stake_registry
        .registerOperatorWithSignature(operator_signature, signer.clone().address())
        .gas(500000);
    let register_layer_middleware_hash = registeroperator_details_call
        .send()
        .await?
        .get_receipt()
        .await?
        .transaction_hash;

    get_logger().info(
        &format!(
            "Operator registered on AVS successfully :{} , tx_hash :{}",
            signer.address(),
            register_layer_middleware_hash
        ),
        &"",
    );

    Ok(())
}
    

#[tokio::main]
pub async fn main() {
    dotenv().ok();
    init_logger(LogLevel::Info);
    if let Err(e) = register_operator().await {
        eprintln!("Failed to register operator: {:?}", e);
        return;
    }
}
