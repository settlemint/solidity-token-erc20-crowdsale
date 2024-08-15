// SPDX-License-Identifier: FSL-1.1-MIT
// SettleMint.com

pragma solidity ^0.8.24;

import { CrowdSale } from "./library/CrowdSale.sol";

/**
 * @title ExampleCrowdSale
 */
contract ExampleCrowdSale is CrowdSale {
    constructor(
        address priceFeed_,
        address token_,
        address payable wallet_,
        uint256 usdRate_,
        uint256 vestingEndDate_,
        address vestingVault_
    )
        CrowdSale(priceFeed_, token_, wallet_, usdRate_, vestingEndDate_, vestingVault_)
    { }
}
