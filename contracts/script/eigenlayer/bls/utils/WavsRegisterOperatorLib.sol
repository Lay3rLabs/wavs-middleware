// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IStrategyManager} from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {IStrategy} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
import {
    IAllocationManagerTypes,
    IAllocationManager
} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {OperatorSet} from "@eigenlayer/contracts/libraries/OperatorSetLib.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";
import {ReadCoreLib} from "./ReadCoreLib.sol";
import {BLSKeyGenerator} from "./BLSKeyGenerator.sol";

import {
    ISlashingRegistryCoordinator,
    ISlashingRegistryCoordinatorTypes
} from "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IBLSApkRegistryTypes} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";
import {WavsServiceManager} from "src/eigenlayer/bls/WavsServiceManager.sol";

/**
 * @title WavsRegisterOperatorLib
 * @author Lay3rLabs
 * @notice This library contains functions for registering an operator to the WAVS service manager.
 * @dev This library is used to register an operator to the WAVS service manager.
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
    /// @notice The error for the failed to get allocation configuration delay.
    error WavsRegisterOperatorLib__FailedToGetAllocationConfigurationDelay();

    /**
     * @notice The setup operator function.
     * @param coreDeployment The core deployment data.
     * @param lstContractAddress The LST contract address.
     * @param lstStrategyAddress The LST strategy address.
     * @param stakeAmount The stake amount.
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
                console2.log(
                    string.concat(
                        "Minted ", Strings.toString(lstBalance), " LST tokens for operator"
                    )
                );
            } else {
                console2.log(
                    string.concat(
                        "Operator already has LST balance of ", Strings.toString(lstBalance)
                    )
                );
            }

            // Approve the strategy manager to spend the LST tokens
            bool approved = lstToken.approve(coreDeployment.strategyManager, stakeAmount);
            if (!approved) {
                revert WavsRegisterOperatorLib__FailedToApproveLSTTokens();
            }
            console2.log(
                string.concat(
                    "Approved ", Strings.toString(stakeAmount), " LST tokens for StrategyManager"
                )
            );

            // Create a new deposit with the LSTs
            console2.log(
                string.concat(
                    "Creating new deposit for operator ",
                    Strings.toHexString(uint160(operatorAddr), 20)
                )
            );
            uint256 shares = strategyManager.depositIntoStrategy(
                IStrategy(lstStrategyAddress), lstToken, stakeAmount
            );
            console2.log(
                string.concat("Created deposit with ", Strings.toString(shares), " shares")
            );
        } else {
            console2.log(
                string.concat(
                    "Operator ",
                    Strings.toHexString(uint160(operatorAddr), 20),
                    " already has deposits, skipping LST operations"
                )
            );
        }

        IDelegationManager delegationManager = IDelegationManager(coreDeployment.delegationManager);
        if (!delegationManager.isDelegated(operatorAddr)) {
            // TODO: allow to override foo.bar with env variable?
            delegationManager.registerAsOperator(address(0), 0, "foo.bar");
        }
    }

    /**
     * @notice The register to AVS function.
     * @param operatorKey The operator key.
     * @param serviceManagerAddress The service manager address.
     * @param allocationManagerAddress The allocation manager address.
     * @param lstStrategyAddress The LST strategy address.
     */
    function registerToAvs(
        uint256 operatorKey,
        address serviceManagerAddress,
        address allocationManagerAddress,
        address lstStrategyAddress
    ) internal {
        // This is the address for private key forge is running the script as.
        // Calculated from the --private-key argument
        (, address operatorAddr,) = VM.readCallers();

        //  query if already in opset and add if if not in it yet.
        IAllocationManager allocationManager = IAllocationManager(allocationManagerAddress);
        OperatorSet memory opSetQuery = OperatorSet({avs: serviceManagerAddress, id: 0});
        if (!allocationManager.isMemberOfOperatorSet(operatorAddr, opSetQuery)) {
            (bool success, bytes memory result) = address(allocationManager).staticcall(
                abi.encodeWithSignature("ALLOCATION_CONFIGURATION_DELAY()")
            );
            if (!success) {
                revert WavsRegisterOperatorLib__FailedToGetAllocationConfigurationDelay();
            }
            uint32 allocationConfigurationDelay = abi.decode(result, (uint32));
            VM.roll(block.number + allocationConfigurationDelay + 1); // Workaround for testnet, txs can't be in the same block
            IStrategy[] memory strategies = new IStrategy[](1);
            strategies[0] = IStrategy(lstStrategyAddress);
            uint64[] memory newMagnitudes = new uint64[](1);
            // Ref: https://github.com/Layr-Labs/eigenlayer-contracts/blob/734f7361884d24fe51961b342e93dde1290961d0/src/contracts/libraries/SlashingLib.sol#L12
            // 1e18 is 100%
            newMagnitudes[0] = 1e18;

            IAllocationManagerTypes.AllocateParams[] memory allocationMods =
                new IAllocationManagerTypes.AllocateParams[](1);
            allocationMods[0] = IAllocationManagerTypes.AllocateParams({
                operatorSet: OperatorSet({avs: serviceManagerAddress, id: 0}),
                strategies: strategies,
                newMagnitudes: newMagnitudes
            });
            allocationManager.modifyAllocations(operatorAddr, allocationMods);

            uint32[] memory opSetIds = new uint32[](1);
            opSetIds[0] = 0;

            BN254.G1Point memory pubkeyRegistrationMessageHash = ISlashingRegistryCoordinator(
                WavsServiceManager(serviceManagerAddress).getRegistryCoordinator()
            ).pubkeyRegistrationMessageHash(operatorAddr);

            IBLSApkRegistryTypes.PubkeyRegistrationParams memory blsParams =
                BLSKeyGenerator.generateBLSParams(pubkeyRegistrationMessageHash, operatorKey);

            bytes memory data = abi.encode(
                ISlashingRegistryCoordinatorTypes.RegistrationType.NORMAL, "Mock Socket", blsParams
            );
            IAllocationManagerTypes.RegisterParams memory params = IAllocationManagerTypes
                .RegisterParams({avs: serviceManagerAddress, operatorSetIds: opSetIds, data: data});

            allocationManager.registerForOperatorSets(operatorAddr, params);

            console2.log(
                string.concat(
                    "Successfully registered operator ",
                    Strings.toHexString(uint160(operatorAddr), 20),
                    " to operator set [0]"
                )
            );
        } else {
            console2.log(
                string.concat(
                    "Operator ",
                    Strings.toHexString(uint160(operatorAddr), 20),
                    " already registered to operator set [0]"
                )
            );
        }
    }
}
