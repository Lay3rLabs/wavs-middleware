// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC1271Upgradeable} from
    "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";

/**
 * @title MockStakeRegistry
 * @author Lay3rLabs
 * @notice This contract is a mock stake registry for testing the WavsServiceManager contract.
 * @dev This contract is used to test the WavsServiceManager contract.
 */
contract MockStakeRegistry {
    /// @notice The operator to signing key mapping.
    mapping(address => address) public operatorToSigning;
    /// @notice The signing key to operator mapping.
    mapping(address => address) public signingToOperator;
    /// @notice The operator weights mapping.
    mapping(address => uint256) public operatorWeights;
    /// @notice The total weight.
    uint256 public totalWeight;

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
     * @notice The isValidSignature function.
     * @param {digest} The digest.
     * @param {signature} The signature.
     * @return The selector.
     */
    function isValidSignature( // solhint-disable-line use-natspec
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
    function getOperatorWeightAtBlock( // solhint-disable-line use-natspec
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
    function getLastCheckpointTotalWeightAtBlock( // solhint-disable-line use-natspec
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
    function getOperatorSigningKeyAtBlock( // solhint-disable-line use-natspec
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
    function getOperatorForSigningKeyAtBlock( // solhint-disable-line use-natspec
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
