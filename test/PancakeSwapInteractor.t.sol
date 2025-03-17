// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { Test } from "forge-std/Test.sol";
import { PancakeSwapInteractor } from "../src/PancakeSwapInteractor.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockToken } from "./mocks/MockToken.sol";
import { IPancakeFactory } from "../src/interfaces/IPancakeFactory.sol";
import { IPancakeRouter } from "../src/interfaces/IPancakeRouter.sol";

contract PancakeSwapInteractorTest is Test {
    PancakeSwapInteractor public interactor;

    address constant PANCAKE_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant Pancake_WBNBPair = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;
    address constant Pancake_BUSDPair = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;

    uint256 bscFork;
    MockToken public newToken;

    function setUp() public {
        bscFork = vm.createFork("https://bsc-dataseed.binance.org");
        vm.selectFork(bscFork);

        interactor = new PancakeSwapInteractor(PANCAKE_FACTORY, PANCAKE_ROUTER);

        vm.deal(address(this), 100 ether);

        newToken = new MockToken();
        newToken.mint(address(this), 1000000 * 1e18);
    }

    function test_SwapAndAddLiquidity() public {
        uint256 initialBUSDPairBalance = IERC20(Pancake_BUSDPair).balanceOf(address(this));
        uint256 exactTokensOut = 10 * 1e18; // 10 BUSD
        uint256 maxBNBIn = 1 ether;

        interactor.swapAndAddLiquidity{value: maxBNBIn}(BUSD, exactTokensOut, block.timestamp + 1);

        uint256 finalBUSDPairBalance = IERC20(Pancake_BUSDPair).balanceOf(address(this));
        assertGe(finalBUSDPairBalance, initialBUSDPairBalance, "Did not receive enough LP tokens");

        assertEq(address(interactor).balance, 0, "Contract should have no BNB left");
        assertEq(IERC20(WBNB).balanceOf(address(interactor)), 0, "Contract should have no WBNB left");
        assertEq(IERC20(BUSD).balanceOf(address(interactor)), 0, "Contract should have no BUSD left");
    }

    function test_RevertWhenExcessiveInputAmount() public {
        uint256 exactTokensOut = 1000000 * 1e18; // 1M BUSD
        uint256 maxBNBIn = 1 ether;

        vm.expectRevert(PancakeSwapInteractor.ExcessiveInputAmount.selector);
        interactor.swapAndAddLiquidity{value: maxBNBIn}(BUSD, exactTokensOut, block.timestamp + 1);
    }

    function test_RevertWhenPairDoesNotExist() public {
        address fakeToken = address(0x123);
        uint256 exactTokensOut = 10 * 1e18;
        uint256 maxBNBIn = 1 ether;

        vm.expectRevert(PancakeSwapInteractor.PairDoesNotExist.selector);
        interactor.swapAndAddLiquidity{value: maxBNBIn}(fakeToken, exactTokensOut, block.timestamp + 1);
    }

    function test_RevertWhenIdenticalAddresses() public {
        uint256 exactTokensOut = 10 * 1e18;
        uint256 maxBNBIn = 1 ether;

        vm.expectRevert(PancakeSwapInteractor.IdenticalAddresses.selector);
        interactor.swapAndAddLiquidity{value: maxBNBIn}(WBNB, exactTokensOut, block.timestamp + 1);
    }

    function test_RevertWhenZeroAddress() public {
        uint256 exactTokensOut = 10 * 1e18;
        uint256 maxBNBIn = 1 ether;

        vm.expectRevert(PancakeSwapInteractor.ZeroAddress.selector);
        interactor.swapAndAddLiquidity{value: maxBNBIn}(address(0), exactTokensOut, block.timestamp + 1);
    }

    function test_RevertWhenInsufficientLiquidity() public {
        vm.startPrank(address(this));
        
        IPancakeFactory(PANCAKE_FACTORY).createPair(address(newToken), WBNB);
        
        vm.stopPrank();

        uint256 exactTokensOut = 10 * 1e18;
        uint256 maxBNBIn = 1 ether;

        vm.expectRevert(PancakeSwapInteractor.InsufficientLiquidity.selector);
        interactor.swapAndAddLiquidity{value: maxBNBIn}(
            address(newToken),
            exactTokensOut,
            block.timestamp + 1
        );
    }

    function test_RevertWhenInsufficientInputAmount() public {
        uint256 exactTokensOut = 0; 
        uint256 maxBNBIn = 1 ether;

        vm.expectRevert(PancakeSwapInteractor.InsufficientInputAmount.selector);
        interactor.swapAndAddLiquidity{value: maxBNBIn}(
            BUSD,
            exactTokensOut,
            block.timestamp + 1
        );
    }

    function test_ReturnUnusedTokens() public {
        uint256 exactTokensOut = 1000 * 1e18; // 10 BUSD
        uint256 maxBNBIn = 2 ether; 
        
        interactor.swapAndAddLiquidity{value: maxBNBIn}(
            BUSD,
            exactTokensOut,
            block.timestamp + 1
        );

        assertEq(IERC20(BUSD).balanceOf(address(interactor)), 0, "Contract should have no BUSD left");
        assertEq(IERC20(WBNB).balanceOf(address(interactor)), 0, "Contract should have no WBNB left");
        assertEq(address(interactor).balance, 0, "Contract should have no BNB left");
        
        uint256 finalTokenBalance = IERC20(BUSD).balanceOf(address(this));
        assertGt(finalTokenBalance, 0, "Should get some tokens back");
    }

    function test_SwapWithCAKE() public {
        uint256 exactTokensOut = 1 * 1e18; // 10 BUSD
        uint256 maxBNBIn = 2 ether; 
        
        interactor.swapAndAddLiquidity{value: maxBNBIn}(
            CAKE,
            exactTokensOut,
            block.timestamp + 1
        );

        assertEq(IERC20(BUSD).balanceOf(address(interactor)), 0, "Contract should have no BUSD left");
        assertEq(IERC20(WBNB).balanceOf(address(interactor)), 0, "Contract should have no WBNB left");
        assertEq(address(interactor).balance, 0, "Contract should have no BNB left");
    }


    receive() external payable {}
}
