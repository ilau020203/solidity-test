// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/PancakeSwapInteractor.sol";

contract DeployPancakeSwapInteractor is Script {
    address constant PANCAKE_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        PancakeSwapInteractor interactor = new PancakeSwapInteractor(PANCAKE_FACTORY, PANCAKE_ROUTER);

        console.log("PancakeSwapInteractor deployed at:", address(interactor));

        vm.stopBroadcast();
    }
}
