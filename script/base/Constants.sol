// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

/// @notice Shared constants used in scripts
contract Constants {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    /// @dev populated with Unichain Sepolia addresses
    IPoolManager constant POOLMANAGER = IPoolManager(address(0xc81462fec8b23319f288047f8a03a57682a35c1a));
    PositionManager constant posm = PositionManager(payable(address(0xb433cb9bcdf4cfcc5cab7d34f90d1a7deefd27b9)));
    /// @dev populated with default anvil addresses
    IAllowanceTransfer constant PERMIT2 = IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
}
