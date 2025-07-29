// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {console2} from "forge-std/console2.sol";
import {IStrategyManager} from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {IStrategy} from "@eigenlayer/contracts/interfaces/IStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title WavsDepositIntoStrategyLib
 * @author Lay3rLabs
 * @notice This library is used to deposit into a WAVS strategy.
 * @dev This library is used to deposit into a WAVS strategy.
 */
library WavsDepositIntoStrategyLib {
    using Strings for *;

    /// @notice The error for the failed to approve LST tokens.
    error WavsDepositIntoStrategy__FailedToApproveLSTTokens();
    /// @notice The error for the failed to mint LST tokens.
    error WavsDepositIntoStrategy__FailedToMintLSTTokens();

    /**
     * @notice The function to deposit into a strategy.
     * @param _strategyManagerAddress The address of the strategy manager.
     * @param _delegationManagerAddress The address of the delegation manager.
     * @param _lstContractAddress The address of the LST contract.
     * @param _lstStrategyAddress The address of the LST strategy.
     * @param _operatorAddr The address of the operator.
     * @param _stakeAmount The amount of LST to stake.
     */
    function depositIntoStrategy(
        address _strategyManagerAddress,
        address _delegationManagerAddress,
        address _lstContractAddress,
        address _lstStrategyAddress,
        address _operatorAddr,
        uint256 _stakeAmount
    ) internal {
        IStrategyManager strategyManager = IStrategyManager(_strategyManagerAddress);
        uint256 numDeposit = strategyManager.stakerStrategyListLength(_operatorAddr);
        if (numDeposit == 0) {
            // Check if operator already has LST balance
            IERC20 lstToken = IERC20(_lstContractAddress);
            uint256 lstBalance = lstToken.balanceOf(_operatorAddr);

            // Only mint LSTs if operator has no balance
            if (lstBalance < _stakeAmount) {
                console2.log("Operator has insufficient LST balance, minting new tokens");

                uint256 amountToMint = _stakeAmount - lstBalance;

                // Call the submit function on the LST contract with the operator as the referral
                (bool success,) = _lstContractAddress.call{value: amountToMint}(
                    abi.encodeWithSignature("submit(address)", _operatorAddr)
                );
                if (!success) {
                    revert WavsDepositIntoStrategy__FailedToMintLSTTokens();
                }

                // Update the LST balance after minting
                lstBalance = lstToken.balanceOf(_operatorAddr);
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
            bool approved = lstToken.approve(_strategyManagerAddress, _stakeAmount);
            if (!approved) {
                revert WavsDepositIntoStrategy__FailedToApproveLSTTokens();
            }
            console2.log(
                string.concat(
                    "Approved ", Strings.toString(_stakeAmount), " LST tokens for StrategyManager"
                )
            );

            // Create a new deposit with the LSTs
            console2.log(
                string.concat(
                    "Creating new deposit for operator ",
                    Strings.toHexString(uint160(_operatorAddr), 20)
                )
            );
            uint256 shares = strategyManager.depositIntoStrategy(
                IStrategy(_lstStrategyAddress), lstToken, _stakeAmount
            );
            console2.log(
                string.concat("Created deposit with ", Strings.toString(shares), " shares")
            );
        } else {
            console2.log(
                string.concat(
                    "Operator ",
                    Strings.toHexString(uint160(_operatorAddr), 20),
                    " already has deposits, skipping LST operations"
                )
            );
        }

        IDelegationManager delegationManager = IDelegationManager(_delegationManagerAddress);
        if (!delegationManager.isDelegated(_operatorAddr)) {
            // TODO: allow to override foo.bar with env variable?
            delegationManager.registerAsOperator(address(0), 0, "foo.bar");
            console2.log("Registered operator as operator");
        }
    }
}
