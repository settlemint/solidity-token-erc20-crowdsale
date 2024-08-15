// SPDX-License-Identifier: FSL-1.1-MIT
// SettleMint.com

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVestingVault {
    struct Vesting {
        // Beneficiary of tokens after they are released
        address beneficiary;
        // Timestamp when token release is enabled
        uint256 releaseTime;
        // Amount of tokens to release
        uint256 tokenAmount;
    }

    event VestingLockedIn(address indexed beneficiary, uint256 releaseTime, uint256 tokenAmount);
    event VestingReleased(address indexed beneficiary, uint256 releaseTime, uint256 tokenAmount);

    function addBeneficiary(address beneficiary_, uint256 releaseTime_, uint256 tokenAmount_) external;

    function token() external view returns (IERC20);

    function vestingFor(address beneficary_) external view returns (Vesting[] memory);

    function release() external;
}
