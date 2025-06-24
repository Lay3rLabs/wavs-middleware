// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {ISignatureUtilsMixinTypes} from "@eigenlayer/contracts/interfaces/ISignatureUtilsMixin.sol";

import {WavsServiceManager} from "../src/WavsServiceManager.sol";

contract WavsDelegateToOperator is Script {
    // Environment variables
    string public constant ENV_OPERATOR = "OPERATOR_ADDRESS";
    string public constant ENV_SERVICE_MANAGER = "WAVS_SERVICE_MANAGER_ADDRESS";
    string public constant ENV_DELEGATION_MANAGER = "DELEGATION_MANAGER_ADDRESS";
    string public constant ENV_DELEGATION_APPROVER_PRIVATE_KEY = "DELEGATION_APPROVER_PRIVATE_KEY";
    string public constant ENV_DELEGATION_APPROVER_SALT = "DELEGATION_APPROVER_SALT";
    string public constant ENV_DELEGATION_DURATION = "DELEGATION_DURATION";

    // Configuration
    address private operatorAddress;
    address private delegationApproverAddress;
    uint256 private approverPrivateKey;
    bytes32 private approverSalt;
    uint256 private delegationDuration;
    IDelegationManager private delegationManager;

    WavsServiceManager public wavsServiceManager;

    error WavsDelegateToOperator__InvalidApproverPrivateKey();

    function setUp() public virtual {
        wavsServiceManager = WavsServiceManager(vm.envAddress(ENV_SERVICE_MANAGER));
        delegationManager = IDelegationManager(vm.envAddress(ENV_DELEGATION_MANAGER));
        operatorAddress = vm.envAddress(ENV_OPERATOR);
        delegationApproverAddress = delegationManager.delegationApprover(operatorAddress);

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

        ISignatureUtilsMixinTypes.SignatureWithExpiry memory approverSignatureAndExpiry;

        if (delegationApproverAddress == address(0)) {
            approverSignatureAndExpiry =
                ISignatureUtilsMixinTypes.SignatureWithExpiry({signature: bytes(""), expiry: 0});
        } else {
            approverSignatureAndExpiry = _createDelegationApprovalSignature(
                vm.addr(vm.envUint("STAKER_KEY")),
                operatorAddress,
                approverPrivateKey,
                approverSalt,
                delegationDuration
            );
        }
        delegationManager.delegateTo(operatorAddress, approverSignatureAndExpiry, approverSalt);

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
}
