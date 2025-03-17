// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IPancakeRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PancakeSwapInteractor {
    IPancakeFactory public immutable factory;
    IPancakeRouter public immutable router;
    address public immutable WETH;

    constructor(address _factory, address _router) {
        factory = IPancakeFactory(_factory);
        router = IPancakeRouter(_router);
        WETH = router.WETH();
    }

    receive() external payable {}


}
