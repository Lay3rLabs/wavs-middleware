//! Start creating tasks and respond appropriately
//! testing utils
/// Register WAVS Operator
pub mod register_wavs_operator;
/// Create createNewTask at regular intervals with random task names
pub mod spam_tasks;
/// test utils
#[cfg(test)]
pub mod test_utils;
/// Register Operator and monitor for NewTaskCreated event
/// Validate signature
pub mod validate_signature;
