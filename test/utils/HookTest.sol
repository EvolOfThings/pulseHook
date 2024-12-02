// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {MockERC20} from "./MockERC20.sol";
import {PulseCheckLiquidityHook} from "../../src/PulseCheckLiquidityHook.sol";
import {HookMiner} from "./HookMiner.sol";

contract HookTest is Test {
    using PoolIdLibrary for PoolKey;

    PoolManager manager;
    MockERC20 token0;
    MockERC20 token1;

    bytes constant ZERO_BYTES = new bytes(0);
    uint160 constant SQRT_RATIO_1_1 = 79228162514264337593543950336;
    uint160 constant MIN_SQRT_RATIO = 4295128739;
    uint160 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    function setUp() public virtual {
        // Deploy the pool manager with a valid address as the protocol fee controller
        manager = new PoolManager(address(this));

        // Deploy test tokens
        token0 = new MockERC20("TestToken0", "TEST0", 18);
        token1 = new MockERC20("TestToken1", "TEST1", 18);
    }

    function deployHook(uint160 flags) internal returns (address) {
        // Deploy the hook with the correct flags
        bytes memory creationCode = type(PulseCheckLiquidityHook).creationCode;
        bytes memory constructorArgs = abi.encode(address(manager));

        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(address(this), flags, creationCode, constructorArgs);

        // Deploy the hook with the mined salt
        vm.prank(address(this));
        PulseCheckLiquidityHook hook = new PulseCheckLiquidityHook{salt: salt}(manager);
        require(address(hook) == hookAddress, "HookTest: hook address mismatch");

        return hookAddress;
    }
}
