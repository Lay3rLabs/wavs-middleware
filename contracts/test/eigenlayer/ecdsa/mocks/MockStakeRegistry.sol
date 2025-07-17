pragma solidity ^0.8.27;

import {IERC1271Upgradeable} from
    "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";

contract MockStakeRegistry {
    mapping(address => address) public operatorToSigning;
    mapping(address => address) public signingToOperator;
    mapping(address => uint256) public operatorWeights;
    uint256 public totalWeight;

    function setOperatorWeight(address operator, uint256 weight) external {
        operatorWeights[operator] = weight;
        // set this to self
        operatorToSigning[operator] = operator;
        signingToOperator[operator] = operator;
    }

    function setOperatorSigner(address operator, address signer) external {
        address oldSigner = operatorToSigning[operator];
        delete signingToOperator[oldSigner];
        operatorToSigning[operator] = signer;
        signingToOperator[signer] = operator;
    }

    function setTotalWeight(
        uint256 _totalWeight
    ) external {
        totalWeight = _totalWeight;
    }

    function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) {
        return IERC1271Upgradeable.isValidSignature.selector;
    }

    function getOperatorWeightAtBlock(address operator, uint32) external view returns (uint256) {
        return operatorWeights[operator];
    }

    function getLastCheckpointTotalWeightAtBlock(
        uint32
    ) external view returns (uint256) {
        return totalWeight;
    }

    function getLastCheckpointOperatorWeight(
        address operator
    ) external view returns (uint256) {
        return operatorWeights[operator];
    }

    function getOperatorSigningKeyAtBlock(
        address operator,
        uint256
    ) external view returns (address) {
        return operatorToSigning[operator];
    }

    function getLatestOperatorSigningKey(
        address operator
    ) external view returns (address) {
        return operatorToSigning[operator];
    }

    function getOperatorForSigningKeyAtBlock(
        address signing,
        uint256
    ) external view returns (address) {
        return signingToOperator[signing];
    }

    function getLatestOperatorForSigningKey(
        address signing
    ) external view returns (address) {
        return signingToOperator[signing];
    }
}
