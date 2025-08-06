// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC1271Upgradeable} from
    "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {IECDSAStakeRegistryErrors} from
    "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";

/**
 * @title MockStakeRegistry
 * @author Lay3rLabs
 * @notice This contract is a mock stake registry for testing the WavsServiceManager contract.
 * @dev This contract is used to test the WavsServiceManager contract.
 */
contract MockStakeRegistry is IECDSAStakeRegistryErrors {
    /// @notice The operator to signing key mapping.
    mapping(address => address) public operatorToSigning;
    /// @notice The signing key to operator mapping.
    mapping(address => address) public signingToOperator;
    /// @notice The operator weights mapping.
    mapping(address => uint256) public operatorWeights;
    /// @notice The total weight.
    uint256 public totalWeight;
    /// @notice The total operators.
    uint256 public totalOperators;

    /**
     * @notice The setOperatorWeight function.
     * @param operator The operator.
     * @param weight The weight.
     */
    function setOperatorWeight(address operator, uint256 weight) external {
        operatorWeights[operator] = weight;
        // set this to self
        operatorToSigning[operator] = operator;
        signingToOperator[operator] = operator;
    }

    /**
     * @notice The setOperatorSigner function.
     * @param operator The operator.
     * @param signer The signer.
     */
    function setOperatorSigner(address operator, address signer) external {
        address oldSigner = operatorToSigning[operator];
        delete signingToOperator[oldSigner];
        operatorToSigning[operator] = signer;
        signingToOperator[signer] = operator;
    }

    /**
     * @notice The setTotalWeight function.
     * @param _totalWeight The total weight.
     */
    function setTotalWeight(
        uint256 _totalWeight
    ) external {
        totalWeight = _totalWeight;
    }

    /**
     * @notice The setTotalOperators function.
     * @param _totalOperators The total operators.
     */
    function setTotalOperators(
        uint256 _totalOperators
    ) external {
        totalOperators = _totalOperators;
    }

    /* solhint-disable use-natspec */
    /**
     * @notice The updateOperatorsForQuorum function.
     * @param operatorsPerQuorum The operators per quorum.
     * @param {_signature} The signature.
     * @dev This function doubles the weights of even operators and halves the weights of odd operators, for testing.
     */
    function updateOperatorsForQuorum(
        address[][] calldata operatorsPerQuorum,
        bytes calldata /* _signature */
    ) external virtual {
        address[] memory operators = operatorsPerQuorum[0];
        if (operators.length != totalOperators) {
            revert MustUpdateAllOperators();
        }
        int256 delta;
        for (uint256 i; i < operators.length; ++i) {
            uint256 oldWeight = operatorWeights[operators[i]];
            uint256 newWeight;
            if (i % 2 == 0) {
                newWeight = oldWeight * 2;
            } else {
                newWeight = oldWeight / 2;
            }
            delta += int256(newWeight) - int256(oldWeight);
            operatorWeights[operators[i]] = newWeight;
        }
        totalWeight = uint256(int256(totalWeight) + delta);
    }

    /**
     * @notice The isValidSignature function.
     * @param {digest} The digest.
     * @param {signature} The signature.
     * @return The selector.
     */
    function isValidSignature(
        bytes32, /* digest */
        bytes calldata /* signature */
    ) external pure returns (bytes4) {
        return IERC1271Upgradeable.isValidSignature.selector;
    }

    /**
     * @notice The getOperatorWeightAtBlock function.
     * @param operator The operator.
     * @param {blockNumber} The block number.
     * @return The operator weight.
     */
    function getOperatorWeightAtBlock(
        address operator,
        uint32 /* blockNumber */
    ) external view returns (uint256) {
        return operatorWeights[operator];
    }

    /**
     * @notice The getLastCheckpointTotalWeightAtBlock function.
     * @param {blockNumber} The block number.
     * @return The total weight.
     */
    function getLastCheckpointTotalWeightAtBlock(
        uint32 /* blockNumber */
    ) external view returns (uint256) {
        return totalWeight;
    }

    /**
     * @notice The getLastCheckpointOperatorWeight function.
     * @param operator The operator.
     * @return The operator weight.
     */
    function getLastCheckpointOperatorWeight(
        address operator
    ) external view returns (uint256) {
        return operatorWeights[operator];
    }

    /**
     * @notice The getOperatorSigningKeyAtBlock function.
     * @param operator The operator.
     * @param {blockNumber} The block number.
     * @return The signing key.
     */
    function getOperatorSigningKeyAtBlock(
        address operator,
        uint256 /* blockNumber */
    ) external view returns (address) {
        return operatorToSigning[operator];
    }

    /**
     * @notice The getLatestOperatorSigningKey function.
     * @param operator The operator.
     * @return The signing key.
     */
    function getLatestOperatorSigningKey(
        address operator
    ) external view returns (address) {
        return operatorToSigning[operator];
    }

    /**
     * @notice The getOperatorForSigningKeyAtBlock function.
     * @param signing The signing key.
     * @param {blockNumber} The block number.
     * @return The operator.
     */
    function getOperatorForSigningKeyAtBlock(
        address signing,
        uint256 /* blockNumber */
    ) external view returns (address) {
        return signingToOperator[signing];
    }

    /**
     * @notice The getLatestOperatorForSigningKey function.
     * @param signing The signing key.
     * @return The operator.
     */
    function getLatestOperatorForSigningKey(
        address signing
    ) external view returns (address) {
        return signingToOperator[signing];
    }
}
