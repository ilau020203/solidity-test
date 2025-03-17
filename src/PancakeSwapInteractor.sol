// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { IPancakeFactory } from "./interfaces/IPancakeFactory.sol";
import { IPancakePair } from "./interfaces/IPancakePair.sol";
import { IPancakeRouter } from "./interfaces/IPancakeRouter.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PancakeSwapInteractor {
    using SafeERC20 for IERC20;

    IPancakeFactory public immutable factory;
    IPancakeRouter public immutable router;
    address public immutable WETH;
    bytes32 public immutable INIT_CODE_HASH;

    error PairDoesNotExist();
    error ExcessiveInputAmount();
    error InsufficientInputAmount();
    error InsufficientLiquidity();
    error IdenticalAddresses();
    error ZeroAddress();

    constructor(address _factory, address _router) {
        factory = IPancakeFactory(_factory);
        router = IPancakeRouter(_router);
        WETH = router.WETH();
        INIT_CODE_HASH = factory.INIT_CODE_PAIR_HASH();
    }

    function swapAndAddLiquidity(address token, uint256 exactTokensOut, uint256 deadline) external payable {
        _wrapBNB();

        uint256 tokensBought = _swapEthForExactTokensViaFactory(token, exactTokensOut, msg.value);
        uint256 unusedBNB = IERC20(WETH).balanceOf(address(this));

        IERC20(token).safeIncreaseAllowance(address(router), tokensBought);
        IERC20(WETH).safeIncreaseAllowance(address(router), unusedBNB);

        router.addLiquidity(WETH, token, unusedBNB, tokensBought, 0, 0, msg.sender, deadline);

        uint256 remainingWBNB = IERC20(WETH).balanceOf(address(this));
        if (remainingWBNB > 0) {
            IERC20(WETH).safeTransfer(msg.sender, remainingWBNB);
        }

        uint256 remainingTokens = IERC20(token).balanceOf(address(this));
        if (remainingTokens > 0) {
            IERC20(token).safeTransfer(msg.sender, remainingTokens);
        }
    }

    function _wrapBNB() internal {
        if (address(this).balance > 0) {
            IWETH(WETH).deposit{value: address(this).balance}();
        }
    }

    function _swapEthForExactTokensViaFactory(address token, uint256 exactTokensOut, uint256 maxBNBIn)
        internal
        returns (uint256)
    {
        address pair = _pairFor(address(factory), WETH, token);
        require(pair != address(0) && pair.code.length != 0, PairDoesNotExist());

        IPancakePair pancakePair = IPancakePair(pair);

        (uint112 reserve0, uint112 reserve1,) = pancakePair.getReserves();

        (address token0,) = _sortTokens(WETH, token);
        (uint256 reserveBNB, uint256 reserveToken) =
            token0 == WETH ? (uint256(reserve0), uint256(reserve1)) : (uint256(reserve1), uint256(reserve0));

        uint256 bnbNeeded = _getAmountIn(exactTokensOut, reserveBNB, reserveToken);

        require(bnbNeeded <= maxBNBIn, ExcessiveInputAmount());

        IERC20(WETH).safeTransfer(pair, bnbNeeded);

        if (token0 == WETH) {
            pancakePair.swap(0, exactTokensOut, address(this), new bytes(0));
        } else {
            pancakePair.swap(exactTokensOut, 0, address(this), new bytes(0));
        }

        return exactTokensOut;
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, IdenticalAddresses());
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), ZeroAddress());
    }

    function _pairFor(address factoryAddress, address tokenA, address tokenB) internal view returns (address pair) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff", factoryAddress, keccak256(abi.encodePacked(token0, token1)), INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }

    function _getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut != 0, InsufficientInputAmount());
        require(reserveIn != 0 && reserveOut != 0, InsufficientLiquidity());

        uint256 numerator = reserveIn * amountOut * 10000;
        uint256 denominator = (reserveOut - amountOut) * 9975;
        amountIn = (numerator / denominator) + 1;
    }
}
