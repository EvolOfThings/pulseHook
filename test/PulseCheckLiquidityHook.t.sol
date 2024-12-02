// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {HookTest} from "./utils/HookTest.sol";
import {PulseCheckLiquidityHook} from "../src/PulseCheckLiquidityHook.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";

contract PulseCheckLiquidityHookTest is HookTest, IUnlockCallback {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    PulseCheckLiquidityHook hook;
    PoolKey poolKey;
    PoolId poolId;

    // Test user addresses
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // Constants for price limits
    uint160 constant MIN_PRICE_LIMIT = uint160(4295128739);
    uint160 constant MAX_PRICE_LIMIT = uint160(1461446703485210103287273052203988822378723970342);

    function setUp() public override {
        super.setUp();
        
        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG | 
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.AFTER_SWAP_FLAG
        );
        hook = PulseCheckLiquidityHook(deployHook(flags));

        // Create the pool
        poolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
        poolId = poolKey.toId();
        manager.initialize(poolKey, SQRT_RATIO_1_1);

        // Give tokens to test users
        token0.mint(alice, 100 ether);
        token1.mint(alice, 100 ether);
        token0.mint(bob, 100 ether);
        token1.mint(bob, 100 ether);
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        require(msg.sender == address(manager), "Only manager can call");

        (bytes memory innerData) = abi.decode(data, (bytes));
        (address sender, bytes memory actionData) = abi.decode(innerData, (address, bytes));

        // Try to decode as ModifyLiquidityParams first
        try this.decodeLiquidityParams(actionData) returns (
            bool _isLiquidity,
            PoolKey memory _key,
            IPoolManager.ModifyLiquidityParams memory _params,
            bytes memory _hookData
        ) {
            if (_isLiquidity) {
                vm.prank(sender);
                (BalanceDelta delta, BalanceDelta fees) = manager.modifyLiquidity(_key, _params, _hookData);
                return abi.encode(delta);
            }
        } catch {}

        // If not liquidity params, must be swap params
        (PoolKey memory _key, IPoolManager.SwapParams memory _params, bytes memory _hookData) = 
            abi.decode(actionData, (PoolKey, IPoolManager.SwapParams, bytes));
        
        vm.prank(sender);
        BalanceDelta delta = manager.swap(_key, _params, _hookData);
        return abi.encode(delta);
    }

    function decodeLiquidityParams(bytes memory data) external pure returns (
        bool isLiquidity,
        PoolKey memory key,
        IPoolManager.ModifyLiquidityParams memory params,
        bytes memory hookData
    ) {
        (key, params, hookData) = abi.decode(data, (PoolKey, IPoolManager.ModifyLiquidityParams, bytes));
        isLiquidity = true;
        return (isLiquidity, key, params, hookData);
    }

    function test_AddLiquidity() public {
        vm.startPrank(alice);
        uint128 liquidity = 1 ether;
        int24 tickLower = -60;
        int24 tickUpper = 60;
        
        // Approve tokens
        token0.approve(address(manager), type(uint256).max);
        token1.approve(address(manager), type(uint256).max);
        
        // Add liquidity
        bytes memory hookData = abi.encode(liquidity, tickLower, tickUpper);
        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int256(uint256(liquidity)),
            salt: bytes32(0)
        });

        // Encode data for unlock
        bytes memory data = abi.encode(alice, abi.encode(poolKey, params, hookData));
        
        // Call unlock and expect success
        manager.unlock(abi.encode(data));
        
        // Verify user is registered
        assertTrue(hook.registeredUsers(poolId, alice), "User not registered");
        vm.stopPrank();
    }

    function test_SwapAndDailyVolume() public {
        // First add liquidity
        test_AddLiquidity();
        
        // Perform a swap
        vm.startPrank(bob);
        token0.approve(address(manager), type(uint256).max);
        token1.approve(address(manager), type(uint256).max);
        
        bytes memory hookData = "";
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: 0.1 ether,
            sqrtPriceLimitX96: MIN_PRICE_LIMIT // Swap as much as possible
        });

        // Encode data for unlock
        bytes memory data = abi.encode(bob, abi.encode(poolKey, params, hookData));
        
        // Call unlock and expect success
        manager.unlock(abi.encode(data));
        
        // Check daily volume was updated
        uint256 dailyVolume = hook.dailyVolume(poolId);
        assertGt(dailyVolume, 0, "Daily volume not updated");
        vm.stopPrank();
    }

    function test_LiquidityAdjustment() public {
        // Setup initial position
        test_AddLiquidity();
        
        // Simulate high volume trading
        vm.startPrank(bob);
        token0.approve(address(manager), type(uint256).max);
        token1.approve(address(manager), type(uint256).max);
        
        // Perform multiple swaps to increase volume
        bytes memory hookData = "";
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: 1 ether,
            sqrtPriceLimitX96: MIN_PRICE_LIMIT
        });
        
        for(uint i = 0; i < 5; i++) {
            // Encode data for unlock
            bytes memory data = abi.encode(bob, abi.encode(poolKey, params, hookData));
            
            // Call unlock and expect success
            manager.unlock(abi.encode(data));
        }
        
        // Verify high volume
        uint256 volume = hook.dailyVolume(poolId);
        assertGt(volume, hook.DAILY_VOLUME_THRESHOLD(), "Volume not high enough");
        vm.stopPrank();
    }
}