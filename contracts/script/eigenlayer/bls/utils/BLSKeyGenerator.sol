// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";
import {
    ISlashingRegistryCoordinator
} from "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IBLSApkRegistryTypes} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {BN256G2} from "@eigenlayer-middleware/test/utils/BN256G2.sol";

/**
 * @title BLSKeyGenerator
 * @author Lay3rLabs
 * @notice This library contains functions for generating BLS keys.
 * @dev This library is used to generate BLS keys.
 */
library BLSKeyGenerator {
    using BN254 for *;
    using Strings for *;

    /**
     * @notice The generate pubkey registration message hash function.
     * @param operator The operator address.
     * @param slashingRegistryCoordinator The slashing registry coordinator address.
     * @return pubkeyRegistrationMessageHash The pubkey registration message hash.
     */
    function generatePubkeyRegistrationMessageHash(
        address operator,
        address slashingRegistryCoordinator
    ) internal view returns (BN254.G1Point memory) {
        return ISlashingRegistryCoordinator(slashingRegistryCoordinator)
            .pubkeyRegistrationMessageHash(operator);
    }

    /**
     * @notice The generate BLS params function.
     * @param pubkeyRegistrationMessageHash The pubkey registration message hash.
     * @param privateKey The private key.
     * @return params The BLS params.
     */
    function generateBLSParams(
        BN254.G1Point memory pubkeyRegistrationMessageHash,
        uint256 privateKey
    ) internal view returns (IBLSApkRegistryTypes.PubkeyRegistrationParams memory params) {
        // Generate G1 public key: P = G1 * privateKey
        BN254.G1Point memory pubkeyG1 = BN254.scalar_mul(BN254.generatorG1(), privateKey);

        // Generate G2 public key: P' = G2 * privateKey using BN254 precompile
        (uint256 g2x0, uint256 g2x1, uint256 g2y0, uint256 g2y1) =
            BN256G2.ECTwistMul(privateKey, BN254.G2x0, BN254.G2x1, BN254.G2y0, BN254.G2y1);
        BN254.G2Point memory pubkeyG2 = BN254.G2Point({X: [g2x1, g2x0], Y: [g2y1, g2y0]});

        // Generate BLS signature: sigma = H(m) * privateKey
        // The pubkeyRegistrationMessageHash is already the hashed message as a G1Point
        BN254.G1Point memory signature = BN254.scalar_mul(pubkeyRegistrationMessageHash, privateKey);

        params = IBLSApkRegistryTypes.PubkeyRegistrationParams({
            pubkeyRegistrationSignature: signature, pubkeyG1: pubkeyG1, pubkeyG2: pubkeyG2
        });
    }
}
