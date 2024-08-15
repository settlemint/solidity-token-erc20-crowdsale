// SPDX-License-Identifier: FSL-1.1-MIT
// SettleMint.com

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ICrowdSale
 */
interface ICrowdSale {
    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    function token() external view returns (IERC20);

    function wallet() external view returns (address payable);

    function fundsRaised() external view returns (uint256);

    function tokensAvailable() external view returns (uint256);

    function buyTokens(address beneficiary) external payable;

    function externalBuyTokens(address beneficiary, uint256 tokenAmount) external;
}
