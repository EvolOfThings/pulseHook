// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";

contract PulseCheckLiquidityHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    // Struct to store user's LP position details
    struct UserPosition {
        uint256 tokenId;
        uint128 liquidity;
        int24 tickLower;
        int24 tickUpper;
        uint256 lastUpdateTimestamp;
        uint256 lastRizzFactor;
    }

    // Mapping to store user positions
    mapping(address => mapping(PoolId => UserPosition)) public userPositions;
    
    // Mapping to store daily trading volume for each pool
    mapping(PoolId => uint256) public dailyVolume;
    
    // Mapping to store last volume update timestamp
    mapping(PoolId => uint256) public lastVolumeUpdate;

    // Hardcoded daily Rizz Factor (can be updated via governance in future)
    uint256 public constant DAILY_RIZZ_FACTOR = 33;

    // Events
    event PositionUpdated(address user, PoolId poolId, uint128 newLiquidity);
    event VolumeUpdated(PoolId poolId, uint256 newVolume);

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // Function to register user's LP position
    function registerPosition(
        PoolKey calldata key,
        uint256 tokenId,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) external {
        PoolId poolId = key.toId();
        UserPosition storage position = userPositions[msg.sender][poolId];
        
        position.tokenId = tokenId;
        position.liquidity = liquidity;
        position.tickLower = tickLower;
        position.tickUpper = tickUpper;
        position.lastUpdateTimestamp = block.timestamp;
        position.lastRizzFactor = DAILY_RIZZ_FACTOR; // Initial Rizz Factor
        
        emit PositionUpdated(msg.sender, poolId, liquidity);
    }

    // Internal function to update position based on Rizz Factor
    function _updatePosition(address user, PoolKey calldata key) internal {
        PoolId poolId = key.toId();
        UserPosition storage position = userPositions[user][poolId];
        
        // Check if 24 hours have passed since last update
        if (block.timestamp < position.lastUpdateTimestamp + 1 days) {
            return;
        }

        uint256 currentVolume = dailyVolume[poolId];
        uint256 volumeDelta = 0;
        
        // Calculate volume delta if we have previous volume data
        if (lastVolumeUpdate[poolId] > 0) {
            if (currentVolume > dailyVolume[poolId]) {
                volumeDelta = currentVolume - dailyVolume[poolId];
            }
        }

        // Calculate interest delta (difference in Rizz Factor)
        int256 interestDelta = int256(DAILY_RIZZ_FACTOR) - int256(position.lastRizzFactor);
        
        // Update liquidity based on interest delta and volume
        uint128 newLiquidity = position.liquidity;
        if (interestDelta < 0 && volumeDelta == 0) {
            // Decrease liquidity by 10% if negative interest and no volume increase
            newLiquidity = uint128(uint256(position.liquidity) * 90 / 100);
        } else if (interestDelta > 0 && volumeDelta > 0) {
            // Increase liquidity by 10% if positive interest and volume increase
            newLiquidity = uint128(uint256(position.liquidity) * 110 / 100);
        }

        // Update position
        if (newLiquidity != position.liquidity) {
            position.liquidity = newLiquidity;
            position.lastUpdateTimestamp = block.timestamp;
            position.lastRizzFactor = DAILY_RIZZ_FACTOR;
            
            emit PositionUpdated(user, poolId, newLiquidity);
        }
    }

    // Hook functions
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        _updatePosition(sender, key);
        return BaseHook.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        _updatePosition(sender, key);
        return BaseHook.beforeRemoveLiquidity.selector;
    }

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        _updatePosition(sender, key);
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4, int128) {
        // Update daily volume
        PoolId poolId = key.toId();
        uint256 swapAmount = uint256(uint128(abs(delta.amount0())));
        dailyVolume[poolId] += swapAmount;
        lastVolumeUpdate[poolId] = block.timestamp;
        
        emit VolumeUpdated(poolId, dailyVolume[poolId]);
        
        return (BaseHook.afterSwap.selector, 0);
    }

    // Helper function to get absolute value
    function abs(int256 x) internal pure returns (int256) {
        return x >= 0 ? x : -x;
    }
}
