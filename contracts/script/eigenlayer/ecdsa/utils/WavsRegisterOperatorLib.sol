// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {ISignatureUtilsMixinTypes} from "@eigenlayer/contracts/interfaces/ISignatureUtilsMixin.sol";
import {IStrategyManager} from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {
    IAllocationManagerTypes,
    IAllocationManager
} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {OperatorSet} from "@eigenlayer/contracts/libraries/OperatorSetLib.sol";
import {IStrategy} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {WavsServiceManager} from "src/eigenlayer/ecdsa/WavsServiceManager.sol";
import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";
import {ReadCoreLib} from "./ReadCoreLib.sol";

/**
 * @title WavsRegisterOperatorLib
 * @author Lay3rLabs
 * @notice This library contains functions for registering operators to the WavsServiceManager contract.
 * @dev This library is used to register operators to the WavsServiceManager contract.
 */
library WavsRegisterOperatorLib {
    using stdJson for *;
    using Strings for *;
    using UpgradeableProxyLib for address;

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice The error for the failed to mint LST tokens.
    error WavsRegisterOperatorLib__FailedToMintLSTTokens();
    /// @notice The error for the failed to approve LST tokens.
    error WavsRegisterOperatorLib__FailedToApproveLSTTokens();

    /**
     * @notice The setup operator function.
     * @param coreDeployment The deployment data.
     * @param lstContractAddress The LST contract address.
     * @param lstStrategyAddress The LST strategy address.
     * @param stakeAmount The amount to stake.
     */
    function setupOperator(
        ReadCoreLib.DeploymentData memory coreDeployment,
        address lstContractAddress,
        address lstStrategyAddress,
        uint256 stakeAmount
    ) internal {
        // This is the address for private key forge is running the script as.
        // Calculated from the --private-key argument
        (, address operatorAddr,) = VM.readCallers();

        IStrategyManager strategyManager = IStrategyManager(coreDeployment.strategyManager);
        uint256 numDeposit = strategyManager.stakerStrategyListLength(operatorAddr);
        if (numDeposit == 0) {
            // Check if operator already has LST balance
            IERC20 lstToken = IERC20(lstContractAddress);
            uint256 lstBalance = lstToken.balanceOf(operatorAddr);

            // Only mint LSTs if operator has no balance
            if (lstBalance == 0) {
                console2.log("Operator has no LST balance, minting new tokens");

                // Call the submit function on the LST contract with the operator as the referral
                (bool success,) = lstContractAddress.call{value: stakeAmount}(
                    abi.encodeWithSignature("submit(address)", operatorAddr)
                );
                if (!success) {
                    revert WavsRegisterOperatorLib__FailedToMintLSTTokens();
                }

                // Update the LST balance after minting
                lstBalance = lstToken.balanceOf(operatorAddr);
                console2.log("Minted", lstBalance, "LST tokens for operator");
            } else {
                console2.log("Operator already has LST balance of", lstBalance);
            }

            // Approve the strategy manager to spend the LST tokens
            bool approved = lstToken.approve(coreDeployment.strategyManager, stakeAmount);
            if (!approved) {
                revert WavsRegisterOperatorLib__FailedToApproveLSTTokens();
            }
            console2.log("Approved", stakeAmount, "LST tokens for StrategyManager");

            // Create a new deposit with the LSTs
            console2.log("Creating new deposit for operator");
            uint256 shares = strategyManager.depositIntoStrategy(
                IStrategy(lstStrategyAddress), lstToken, stakeAmount
            );
            console2.log("Created deposit with", shares, "shares");
        } else {
            console2.log("Operator already has deposits, skipping LST operations");
        }

        IDelegationManager delegationManager = IDelegationManager(coreDeployment.delegationManager);
        if (!delegationManager.isDelegated(operatorAddr)) {
            // TODO: allow to override foo.bar with env variable?
            delegationManager.registerAsOperator(address(0), 0, "foo.bar");
        }
    }

    /**
     * @notice The register to AVS function.
     * @param serviceManagerAddress The WAVS service manager address.
     * @param signingKeyAddress The signing key address.
     */
    function registerToAvs(
        address serviceManagerAddress,
        address signingKeyAddress
    ) internal {
        WavsServiceManager serviceManager = WavsServiceManager(serviceManagerAddress);
        ECDSAStakeRegistry stakeRegistry = ECDSAStakeRegistry(serviceManager.stakeRegistry());

        // This is the address for private key forge is running the script as.
        // Calculated from the --private-key argument
        (, address operatorAddr,) = VM.readCallers();

        //  query if already in opset and add if if not in it yet.
        IAllocationManager allocationManager =
            IAllocationManager(serviceManager.getAllocationManager());
        OperatorSet memory opSetQuery = OperatorSet({avs: serviceManagerAddress, id: 0});
        if (!allocationManager.isMemberOfOperatorSet(operatorAddr, opSetQuery)) {
            uint32[] memory opSetIds = new uint32[](1);
            opSetIds[0] = 0;
            // TODO: change this arbitrary code?
            bytes memory secretCode = bytes("0x1234");
            IAllocationManagerTypes.RegisterParams memory params =
                IAllocationManagerTypes.RegisterParams({
                    avs: serviceManagerAddress, operatorSetIds: opSetIds, data: secretCode
                });
            allocationManager.registerForOperatorSets(operatorAddr, params);

            console2.log("Successfully registered operator %s to operator sets [0]", operatorAddr);
        } else {
            console2.log("%s already registered to operator sets [0]", operatorAddr);
        }

        if (!stakeRegistry.operatorRegistered(operatorAddr)) {
            console2.log(
                "Registering operator %s with AVS using signing key %s ...",
                operatorAddr,
                signingKeyAddress
            );
            IAVSDirectory avsDirectory = IAVSDirectory(serviceManager.avsDirectory());

            // TODO: port bash logic
            /*
            # Generate a random salt (32 bytes)
            local salt=$(openssl rand -hex 32)

            # Calculate expiry (current time + 1 hour)
            local expiry=$(($(date +%s) + 3600))

            local digest_hash=$(cast call "$avs_directory_address" "calculateOperatorAVSRegistrationDigestHash(address,address,bytes32,uint256)" "$operator_address" "$WAVS_SERVICE_MANAGER_ADDRESS" "$salt" "$expiry" --rpc-url "$RPC_URL")
            # Remove 0x prefix from digest hash if present
            digest_hash=${digest_hash#0x}
            # Sign the digest hash with the private key
            local signature=$(cast wallet sign $digest_hash --no-hash --private-key "$operator_key")
            */
            // expires in one hour
            uint256 expiry = block.timestamp + 3600;
            bytes32 salt = bytes32("123455"); // TODO: get random
            bytes32 digest = avsDirectory.calculateOperatorAVSRegistrationDigestHash(
                operatorAddr, serviceManagerAddress, salt, expiry
            );
            // local signature=$(cast wallet sign $digest_hash --no-hash --private-key "$operator_key")
            (uint8 v, bytes32 r, bytes32 s) = VM.sign(digest);
            bytes memory signature = abi.encodePacked(r, s, v);

            console2.log("Registering operator with signature...");
            ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry memory operatorSignature =
                ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry({
                    signature: signature, salt: salt, expiry: expiry
                });

            stakeRegistry.registerOperatorWithSignature(operatorSignature, signingKeyAddress);
            console2.log(
                "Successfully registered operator %s with AVS using signing key %s",
                operatorAddr,
                signingKeyAddress
            );
        } else {
            console2.log("Operator %s is already registered with AVS", operatorAddr);
        }
    }

    /**
     * @notice The deregister from AVS function.
     * @param serviceManagerAddress The WAVS service manager address.
     */
    function deregisterFromAvs(
        address serviceManagerAddress
    ) internal {
        WavsServiceManager serviceManager = WavsServiceManager(serviceManagerAddress);
        ECDSAStakeRegistry stakeRegistry = ECDSAStakeRegistry(serviceManager.stakeRegistry());

        // This is the address for private key forge is running the script as.
        // Calculated from the --private-key argument
        (, address operatorAddr,) = VM.readCallers();

        // query if already in opset and add if if not in it yet.
        IAllocationManager allocationManager =
            IAllocationManager(serviceManager.getAllocationManager());
        OperatorSet memory opSetQuery = OperatorSet({avs: serviceManagerAddress, id: 0});
        if (allocationManager.isMemberOfOperatorSet(operatorAddr, opSetQuery)) {
            uint32[] memory opSetIds = new uint32[](1);
            opSetIds[0] = 0;
            IAllocationManagerTypes.DeregisterParams memory params =
                IAllocationManagerTypes.DeregisterParams({
                    operator: operatorAddr, avs: serviceManagerAddress, operatorSetIds: opSetIds
                });
            allocationManager.deregisterFromOperatorSets(params);

            console2.log(
                "Successfully deregistered operator %s from operator sets [0]", operatorAddr
            );
        } else {
            console2.log("%s not registered to operator sets [0]", operatorAddr);
        }

        if (stakeRegistry.operatorRegistered(operatorAddr)) {
            console2.log("Deregistering operator %s with AVS ...", operatorAddr);
            stakeRegistry.deregisterOperator();
            console2.log("Successfully deregistered operator %s with AVS", operatorAddr);
        } else {
            console2.log("Operator %s is not registered with AVS", operatorAddr);
        }
    }
}
