// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

import {Constants} from "./base/Constants.sol";
import {PulseCheckLiquidityHook} from "../src/PulseCheckLiquidityHook.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

/// @notice Script to deploy PulseCheckLiquidityHook
contract DeployPulseHookScript is Script, Constants {
    function setUp() public {}

    function run() public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | 
            Hooks.AFTER_INITIALIZE_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG
        );

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(IPoolManager(POOLMANAGER));
        (address hookAddress, bytes32 salt) = 
            HookMiner.find(CREATE2_DEPLOYER, flags, type(PulseCheckLiquidityHook).creationCode, constructorArgs);

        // Deploy the hook using the mined salt
        vm.broadcast();
        PulseCheckLiquidityHook hook = new PulseCheckLiquidityHook{salt: salt}(IPoolManager(POOLMANAGER));
        require(address(hook) == hookAddress, "DeployPulseHookScript: hook address mismatch");

        console.log("Hook deployed at:", address(hook));
    }
}
