// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PositionManager} from "@uniswap/v4-periphery/src/PositionManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

/// @notice Shared constants used in scripts
contract Constants {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    /// @dev populated with Unichain Sepolia addresses
    IPoolManager constant POOLMANAGER = IPoolManager(address(0xC81462Fec8B23319F288047f8A03A57682a35C1A));
    PositionManager constant posm = PositionManager(payable(address(0xB433cB9BcDF4CfCC5cAB7D34f90d1a7deEfD27b9)));
    /// @dev populated with default anvil addresses
    IAllowanceTransfer constant PERMIT2 = IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
}
