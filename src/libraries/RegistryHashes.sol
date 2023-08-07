// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {IDelegateRegistry} from "../IDelegateRegistry.sol";

/**
 * @title Library for calculating the hashes and storage locations used in the delegate registry
 *
 * The encoding for the 5 types of delegate registry hashes should be as follows
 *
 * ALL:         keccak256(abi.encodePacked(rights, from, to))
 * CONTRACT:    keccak256(abi.encodePacked(rights, from, to, contract_))
 * ERC721:      keccak256(abi.encodePacked(rights, from, to, contract_, tokenId))
 * ERC20:       keccak256(abi.encodePacked(rights, from, to, contract_))
 * ERC1155:     keccak256(abi.encodePacked(rights, from, to, contract_, tokenId))
 *
 * To avoid collisions between the hashes with respect to type, the last byte of the hash is encoded with a unique number representing the type of delegation.
 *
 */
library RegistryHashes {
    /// @dev Used to delete everything but the last byte of a 32 byte word with and(word, EXTRACT_LAST_BYTE)
    uint256 internal constant EXTRACT_LAST_BYTE = 0xFF;
    /// @dev uint256 constant for the delegate registry delegation type enumeration, related unit test should fail if these mismatch
    uint256 internal constant ALL_TYPE = 1;
    uint256 internal constant CONTRACT_TYPE = 2;
    uint256 internal constant ERC721_TYPE = 3;
    uint256 internal constant ERC20_TYPE = 4;
    uint256 internal constant ERC1155_TYPE = 5;
    /// @dev uint256 constant for the location of the delegations array in the delegate registry, assumed to be zero
    uint256 internal constant DELEGATION_SLOT = 0;

    /**
     * @notice Helper function to decode last byte of a delegation hash to obtain its delegation type
     * @param inputHash to decode the type from
     * @return decodedType of the delegation
     * @dev function itself will not revert if decodedType > type(IDelegateRegistry.DelegationType).max
     * @dev may lead to a revert with Conversion into non-existent enum type after the function is called if inputHash was encoded with type outside the DelegationType
     * enum range
     */
    function decodeType(bytes32 inputHash) internal pure returns (IDelegateRegistry.DelegationType decodedType) {
        assembly ("memory-safe") {
            decodedType := and(inputHash, EXTRACT_LAST_BYTE)
        }
    }

    /**
     * @notice Helper function that computes the storage location of a particular delegation array
     * @param inputHash is the hash of the delegation
     * @return computedLocation is the storage key of the delegation array at position 0
     * @dev Storage keys further down the array can be obtained by adding computedLocation with the element position
     * @dev Follows the solidity storage location encoding for a mapping(bytes32 => fixedArray) at the position of the delegationSlot
     */
    function location(bytes32 inputHash) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            mstore(0x00, inputHash) // Store hash in scratch space
            mstore(0x20, DELEGATION_SLOT) // Store delegationSlot after hash in scratch space
            computedLocation := keccak256(0x00, 0x40) // Run keccak256 over bytes in scratch space to obtain the storage key
        }
    }

    /**
     * @notice Helper function to compute delegation hash for all delegation
     * @param from is the address making the delegation
     * @param rights it the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @return hash of the delegation parameters encoded with ALL_TYPE
     * @dev returned hash should be equivalent to keccak256(abi.encodePacked(rights, from, to)) with the last byte overwritten with ALL_TYPE
     * @dev will not revert if from or to are > uint160, any input larger than uint160 for from and to will be cleaned to their last 20 bytes
     */
    function allHash(address from, bytes32 rights, address to) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            // Layout the variables from last to first,
            // agnostic to upper 96 bits of address words.
            mstore(0x28, to)
            mstore(0x14, from)
            mstore(0x00, rights)
            hash := or(shl(8, keccak256(0x00, 0x48)), ALL_TYPE)
            // Restore the upper bits of the free memory pointer, which is zero.
            mstore(0x28, 0)
        }
    }

    /**
     * @notice Helper function to compute delegation location for all delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @return computedLocation is the storage location of the all delegation with those parameters in the delegations mapping
     * @dev gives the same location hash as location(allHash(rights, from, to)) would
     * @dev will not revert if from or to are > uint160, any input larger than uint160 for from and to will be cleaned to their last 20 bytes
     */
    function allLocation(address from, bytes32 rights, address to) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            // Layout the variables from last to first,
            // agnostic to upper 96 bits of address words.
            mstore(0x28, to)
            mstore(0x14, from)
            mstore(0x00, rights)
            mstore(0x08, or(shl(8, keccak256(0x00, 0x48)), ALL_TYPE))
            mstore(0x28, DELEGATION_SLOT)
            computedLocation := keccak256(0x08, 0x40)
            // Restore the upper bits of the free memory pointer, which is zero.
            mstore(0x28, 0)
        }
    }

    /**
     * @notice Helper function to compute delegation hash for contract delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param contract_ is the address of the contract specified by the delegation
     * @return hash of the delegation parameters encoded with CONTRACT_TYPE
     * @dev returned hash should be equivalent to keccak256(abi.encodePacked(rights, from, to, contract_)) with the last byte overwritten with CONTRACT_TYPE
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function contractHash(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            // Layout the variables from last to first,
            // agnostic to upper 96 bits of address words.
            mstore(0x3c, contract_)
            mstore(0x28, to)
            mstore(0x14, from)
            mstore(0x00, rights)
            hash := or(shl(8, keccak256(0x00, 0x5c)), CONTRACT_TYPE)
            // Restore the upper bits of the free memory pointer, which is zero.
            mstore(0x3c, 0)
        }
    }

    /**
     * @notice Helper function to compute delegation location for contract delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param contract_ is the address of the contract specified by the delegation
     * @return computedLocation is the storage location of the contract delegation with those parameters in the delegations mapping
     * @dev gives the same location hash as location(contractHash(rights, from, to, contract_)) would
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function contractLocation(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            // Layout the variables from last to first,
            // agnostic to upper 96 bits of address words.
            mstore(0x3c, contract_)
            mstore(0x28, to)
            mstore(0x14, from)
            mstore(0x00, rights)
            mstore(0x1c, or(shl(8, keccak256(0x00, 0x5c)), CONTRACT_TYPE))
            mstore(0x3c, DELEGATION_SLOT)
            computedLocation := keccak256(0x1c, 0x40)
            // Restore the upper bits of the free memory pointer, which is zero.
            // Should be optimized away if `DELEGATION_SLOT` is zero.
            mstore(0x3c, 0)
        }
    }

    /**
     * @notice Helper function to compute delegation hash for ERC721 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param tokenId is the id of the token specified by the delegation
     * @param contract_ is the address of the contract specified by the delegation
     * @return hash of the parameters encoded with ERC721_TYPE
     * @dev returned hash should be equivalent to keccak256(abi.encodePacked(rights, from, to, contract_, tokenId)) with the last byte overwritten with ERC721_TYPE
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc721Hash(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            let m := mload(0x40) // Cache the free memory pointer.
            // Layout the variables from last to first,
            // agnostic to upper 96 bits of address words.
            mstore(0x5c, tokenId)
            mstore(0x3c, contract_)
            mstore(0x28, to)
            mstore(0x14, from)
            mstore(0x00, rights)
            hash := or(shl(8, keccak256(0x00, 0x7c)), ERC721_TYPE)
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero pointer.
        }
    }

    /**
     * @notice Helper function to compute delegation location for ERC721 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param tokenId is the id of the erc721 token
     * @param contract_ is the address of the erc721 token contract
     * @return computedLocation is the storage location of the erc721 delegation with those parameters in the delegations mapping
     * @dev gives the same location hash as location(erc721Hash(rights, from, to, contract_, tokenId)) would
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc721Location(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            let m := mload(0x40) // Cache the free memory pointer.
            // Layout the variables from last to first,
            // agnostic to upper 96 bits of address words.
            mstore(0x5c, tokenId)
            mstore(0x3c, contract_)
            mstore(0x28, to)
            mstore(0x14, from)
            mstore(0x00, rights)
            mstore(0x40, or(shl(8, keccak256(0x00, 0x7c)), ERC721_TYPE))
            mstore(0x60, DELEGATION_SLOT)
            computedLocation := keccak256(0x40, 0x40)
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero pointer. Should be optimized away if `DELEGATION_SLOT` is zero.
        }
    }

    /**
     * @notice Helper function to compute delegation hash for ERC20 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param contract_ is the address of the erc20 token contract
     * @return hash of the parameters encoded with ERC20_TYPE
     * @dev returned hash should be equivalent to keccak256(abi.encodePacked(rights, from, to, contract_)) with the last byte overwritten with ERC20_TYPE
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc20Hash(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            // Layout the variables from last to first,
            // agnostic to upper 96 bits of address words.
            mstore(0x3c, contract_)
            mstore(0x28, to)
            mstore(0x14, from)
            mstore(0x00, rights)
            hash := or(shl(8, keccak256(0x00, 0x5c)), ERC20_TYPE)
            // Restore the upper bits of the free memory pointer, which is zero.
            mstore(0x3c, 0)
        }
    }

    /**
     * @notice Helper function to compute delegation location for ERC20 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param contract_ is the address of the erc20 token contract
     * @return computedLocation is the storage location of the erc20 delegation with those parameters in the delegations mapping
     * @dev gives the same location hash as location(erc20Hash(rights, from, to, contract_)) would
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc20Location(address from, bytes32 rights, address to, address contract_) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            // Layout the variables from last to first,
            // agnostic to upper 96 bits of address words.
            mstore(0x3c, contract_)
            mstore(0x28, to)
            mstore(0x14, from)
            mstore(0x00, rights)
            mstore(0x1c, or(shl(8, keccak256(0x00, 0x5c)), ERC20_TYPE))
            mstore(0x3c, DELEGATION_SLOT)
            computedLocation := keccak256(0x1c, 0x40)
            // Restore the upper bits of the free memory pointer, which is zero.
            // Should be optimized away if `DELEGATION_SLOT` is zero.
            mstore(0x3c, 0)
        }
    }

    /**
     * @notice Helper function to compute delegation hash for ERC1155 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param tokenId is the id of the erc1155 token
     * @param contract_ is the address of the erc1155 token contract
     * @return hash of the parameters encoded with ERC1155_TYPE
     * @dev returned hash should be equivalent to keccak256(abi.encodePacked(rights, from, to, contract_, tokenId)) with the last byte overwritten with ERC1155_TYPE
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc1155Hash(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            let m := mload(0x40) // Cache the free memory pointer.
            // Layout the variables from last to first,
            // agnostic to upper 96 bits of address words.
            mstore(0x5c, tokenId)
            mstore(0x3c, contract_)
            mstore(0x28, to)
            mstore(0x14, from)
            mstore(0x00, rights)
            hash := or(shl(8, keccak256(0x00, 0x7c)), ERC1155_TYPE)
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero pointer. Should be optimized away if `DELEGATION_SLOT` is zero.
        }
    }

    /**
     * @notice Helper function to compute delegation hash for ERC1155 delegation
     * @param from is the address making the delegation
     * @param rights is the rights specified by the delegation
     * @param to is the address receiving the delegation
     * @param tokenId is the id of the erc1155 token
     * @param contract_ is the address of the erc1155 token contract
     * @return computedLocation is the storage location of the erc1155 delegation with those parameters in the delegations mapping
     * @dev gives the same location hash as location(erc1155Hash(rights, from, to, contract_, tokenId)) would
     * @dev will not revert if from, to, or contract_ are > uint160, any input larger than uint160 for from, to, or contract_ will be cleaned to their last 20 bytes
     */
    function erc1155Location(address from, bytes32 rights, address to, uint256 tokenId, address contract_) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            let m := mload(0x40) // Cache the free memory pointer.
            // Layout the variables from last to first,
            // agnostic to upper 96 bits of address words.
            mstore(0x5c, tokenId)
            mstore(0x3c, contract_)
            mstore(0x28, to)
            mstore(0x14, from)
            mstore(0x00, rights)
            mstore(0x40, or(shl(8, keccak256(0x00, 0x7c)), ERC1155_TYPE))
            mstore(0x60, DELEGATION_SLOT)
            computedLocation := keccak256(0x40, 0x40)
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero pointer. Should be optimized away if `DELEGATION_SLOT` is zero.
        }
    }
}