// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract MaliciousApprove {
    function approve(address token, address _address, uint256 amount) public {
        IERC20(token).approve(_address, amount);
    }
}