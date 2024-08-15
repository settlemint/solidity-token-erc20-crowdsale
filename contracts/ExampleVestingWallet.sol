// SPDX-License-Identifier: FSL-1.1-MIT
// SettleMint.com

pragma solidity ^0.8.24;

import { VestingWallet } from "@openzeppelin/contracts/finance/VestingWallet.sol";

contract ExampleVestingWallet is VestingWallet {
    constructor(
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds
    )
        VestingWallet(beneficiaryAddress, startTimestamp, durationSeconds)
    { }
}
