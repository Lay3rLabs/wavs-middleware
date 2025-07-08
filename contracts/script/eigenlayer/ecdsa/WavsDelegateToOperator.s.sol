// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";
import {DelegationManager} from "@eigenlayer/contracts/core/DelegationManager.sol";
import {ISignatureUtilsMixinTypes} from "@eigenlayer/contracts/interfaces/ISignatureUtilsMixin.sol";
import {IStrategyManager} from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStrategy} from "@eigenlayer/contracts/interfaces/IStrategy.sol";

import {WavsServiceManager} from "src/eigenlayer/ecdsa/WavsServiceManager.sol";

contract WavsDelegateToOperator is Script {
    // Environment variables
    string public constant ENV_OPERATOR = "OPERATOR_ADDRESS";
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";

    string public constant ENV_LST_CONTRACT = "LST_CONTRACT_ADDRESS";
    string public constant ENV_LST_STRATEGY = "LST_STRATEGY_ADDRESS";
    string public constant ENV_AMOUNT = "WAVS_DELEGATE_AMOUNT";

    string public constant ENV_DELEGATION_APPROVER_PRIVATE_KEY = "DELEGATION_APPROVER_PRIVATE_KEY";
    string public constant ENV_DELEGATION_APPROVER_SALT = "DELEGATION_APPROVER_SALT";
    string public constant ENV_DELEGATION_DURATION = "DELEGATION_DURATION";

    // Configuration
    address private operatorAddress;
    address private delegationApproverAddress;
    uint256 private approverPrivateKey;
    bytes32 private approverSalt;
    uint256 private delegationDuration;
    DelegationManager private delegationManager;

    address private lstContractAddress;
    address private lstStrategyAddress;
    uint256 private stakeAmount;

    WavsServiceManager public wavsServiceManager;

    error WavsDelegateToOperator__InvalidApproverPrivateKey();
    error WavsDelegateToOperator__FailedToMintLSTTokens();
    error WavsDelegateToOperator__FailedToApproveLSTTokens();

    function setUp() public virtual {
        wavsServiceManager = WavsServiceManager(vm.envAddress(ENV_SERVICE_MANAGER));
        delegationManager = DelegationManager(wavsServiceManager.getDelegationManager());
        operatorAddress = vm.envAddress(ENV_OPERATOR);
        delegationApproverAddress = delegationManager.delegationApprover(operatorAddress);

        lstContractAddress = vm.envAddress(ENV_LST_CONTRACT);
        lstStrategyAddress = vm.envAddress(ENV_LST_STRATEGY);
        stakeAmount = vm.envUint(ENV_AMOUNT);

        if (delegationApproverAddress != address(0)) {
            approverPrivateKey = vm.envUint(ENV_DELEGATION_APPROVER_PRIVATE_KEY);
            approverSalt = vm.envBytes32(ENV_DELEGATION_APPROVER_SALT);
            delegationDuration = vm.envUint(ENV_DELEGATION_DURATION);
            if (vm.addr(approverPrivateKey) != delegationApproverAddress) {
                revert WavsDelegateToOperator__InvalidApproverPrivateKey();
            }
        }
    }

    function run() external {
        vm.startBroadcast();

        _setUpDelegator();

        ISignatureUtilsMixinTypes.SignatureWithExpiry memory approverSignatureAndExpiry;

        if (delegationApproverAddress == address(0)) {
            approverSignatureAndExpiry =
                ISignatureUtilsMixinTypes.SignatureWithExpiry({signature: bytes(""), expiry: 0});
            delegationManager.delegateTo(operatorAddress, approverSignatureAndExpiry, bytes32(0));
        } else {
            approverSignatureAndExpiry = _createDelegationApprovalSignature(
                vm.addr(vm.envUint("STAKER_KEY")),
                operatorAddress,
                approverPrivateKey,
                approverSalt,
                delegationDuration
            );
            delegationManager.delegateTo(operatorAddress, approverSignatureAndExpiry, approverSalt);
        }

        vm.stopBroadcast();
    }

    function _createDelegationApprovalSignature(
        address _staker,
        address _operator,
        uint256 _approverPrivateKey,
        bytes32 _salt,
        uint256 _duration
    ) internal view returns (ISignatureUtilsMixinTypes.SignatureWithExpiry memory) {
        uint256 expiry = block.timestamp + _duration;

        bytes32 digestHash = delegationManager.calculateDelegationApprovalDigestHash(
            _staker, _operator, vm.addr(_approverPrivateKey), _salt, expiry
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_approverPrivateKey, digestHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        return ISignatureUtilsMixinTypes.SignatureWithExpiry({signature: signature, expiry: expiry});
    }

    function _setUpDelegator() internal {
        // This is the address for private key forge is running the script as.
        // Calculated from the --private-key argument
        (, address delegator,) = vm.readCallers();

        IStrategyManager strategyManager = IStrategyManager(delegationManager.strategyManager());

        uint256 numDeposit = strategyManager.stakerStrategyListLength(delegator);
        if (numDeposit == 0) {
            // Check if operator already has LST balance
            IERC20 lstToken = IERC20(lstContractAddress);
            uint256 lstBalance = lstToken.balanceOf(delegator);

            // Only mint LSTs if operator has no balance
            if (lstBalance == 0) {
                console2.log("Delegator has no LST balance, minting new tokens");

                // Call the submit function on the LST contract with the operator as the referral
                (bool success,) = lstContractAddress.call{value: stakeAmount}(
                    abi.encodeWithSignature("submit(address)", delegator)
                );
                if (!success) {
                    revert WavsDelegateToOperator__FailedToMintLSTTokens();
                }

                // Update the LST balance after minting
                lstBalance = lstToken.balanceOf(delegator);
                console2.log("Minted", lstBalance, "LST tokens for delegator");
            } else {
                console2.log("Delegator already has LST balance of", lstBalance);
            }

            // Approve the strategy manager to spend the LST tokens
            bool approved = lstToken.approve(address(strategyManager), stakeAmount);
            if (!approved) {
                revert WavsDelegateToOperator__FailedToApproveLSTTokens();
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
    }
}
