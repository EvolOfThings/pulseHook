// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Constants} from "./base/Constants.sol";

contract InitializePoolScript is Script, Constants {
    using CurrencyLibrary for Currency;

    // Example token addresses - replace with actual tokens you want to use
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x4200000000000000000000000000000000000007;

    function run() public {
        // Create the pool key
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(WETH),
            currency1: Currency.wrap(USDC),
            fee: 3000, // 0.3% fee tier
            tickSpacing: 60,
            hooks: IHooks(address(0xa32862E752C9133E61FDBEC795dF19b1C2Bf1840)) // Our deployed hook
        });

        // Initialize the pool with initial sqrt price of 1
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // 1.0 price

        vm.broadcast();
        POOLMANAGER.initialize(poolKey, sqrtPriceX96, "");

        console.log("Pool initialized with ID:", PoolIdLibrary.toId(poolKey));
    }
}
