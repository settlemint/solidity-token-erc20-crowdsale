// SPDX-License-Identifier: FSL-1.1-MIT
// SettleMint.com

pragma solidity ^0.8.24;

import { VestingVault } from "./library/VestingVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ExampleVestingVault is VestingVault {
    constructor(IERC20 token_) VestingVault(token_) { }
}
