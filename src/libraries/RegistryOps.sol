// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

library RegistryOps {
    /// @dev `x > y ? x : y`.
    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := xor(x, mul(xor(x, y), gt(y, x)))
        }
    }

    /// @dev `x & y`.
    function and(bool x, bool y) internal pure returns (bool z) {
        assembly {
            z := and(x, y)
        }
    }

    /// @dev `x | y`.
    function or(bool x, bool y) internal pure returns (bool z) {
        assembly {
            z := or(x, y)
        }
    }
}
