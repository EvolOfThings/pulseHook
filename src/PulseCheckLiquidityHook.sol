// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseHook} from "@uniswap/v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

contract PulseCheckLiquidityHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    uint256 public constant DAILY_VOLUME_THRESHOLD = 1000000; // 1M in wei
    uint256 public constant RIZZ_FACTOR = 33; // Hardcoded for now, can be made dynamic later
    uint256 public constant LIQUIDITY_ADJUSTMENT = 10; // 10% adjustment

    mapping(PoolId => uint256) public dailyVolume;
    mapping(PoolId => uint256) public lastVolumeUpdate;
    mapping(PoolId => mapping(address => bool)) public registeredUsers;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function afterInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick
    ) external override returns (bytes4) {
        PoolId poolId = key.toId();
        dailyVolume[poolId] = 0;
        lastVolumeUpdate[poolId] = block.timestamp;
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        PoolId poolId = key.toId();
        
        // Register user if not already registered
        if (!registeredUsers[poolId][sender]) {
            registeredUsers[poolId][sender] = true;
        }

        // Check if 24 hours have passed since last update
        if (block.timestamp >= lastVolumeUpdate[poolId] + 1 days) {
            // Reset daily volume if a new day has started
            dailyVolume[poolId] = 0;
            lastVolumeUpdate[poolId] = block.timestamp;
        }

        // Return the selector for the hook
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        PoolId poolId = key.toId();
        
        // Update daily volume
        uint256 swapAmount;
        if (params.zeroForOne) {
            int256 amount = abs(delta.amount0());
            swapAmount = uint256(amount);
        } else {
            int256 amount = abs(delta.amount1());
            swapAmount = uint256(amount);
        }
        dailyVolume[poolId] += swapAmount;
        
        return (IHooks.afterSwap.selector, 0);
    }

    // Helper function to get absolute value
    function abs(int256 x) internal pure returns (int256) {
        return x >= 0 ? x : -x;
    }
}
