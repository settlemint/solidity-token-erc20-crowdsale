// SPDX-License-Identifier: FSL-1.1-MIT
// SettleMint.com

pragma solidity ^0.8.24;

import { IVestingVault } from "./IVestingVault.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VestingVault
 */
contract VestingVault is IVestingVault, ERC165, AccessControl {
    bytes32 public constant VAULT_CONTROLLER_ROLE = keccak256("VAULT_CONTROLLER_ROLE");
    IERC20 private immutable _token;
    mapping(address => Vesting[]) private _vesting;

    constructor(IERC20 token_) {
        _token = token_;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(VAULT_CONTROLLER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, AccessControl) returns (bool) {
        return interfaceId == type(IVestingVault).interfaceId || super.supportsInterface(interfaceId); // ERC165
    }

    /**
     * @dev function to create a vesting for the beneficiary
     * @param beneficiary_ Beneficiary of tokens after they are released
     * @param releaseTime_ Timestamp when token release is enabled
     * @param tokenAmount_ Amount of tokens to release
     */
    function addBeneficiary(
        address beneficiary_,
        uint256 releaseTime_,
        uint256 tokenAmount_
    )
        public
        override
        onlyRole(VAULT_CONTROLLER_ROLE)
    {
        Vesting[] memory vestings = _vesting[beneficiary_];

        for (uint256 i = 0; i < vestings.length; i++) {
            if (releaseTime_ == vestings[i].releaseTime) {
                _vesting[beneficiary_][i].tokenAmount += tokenAmount_;
                emit VestingLockedIn(beneficiary_, releaseTime_, tokenAmount_);
                return;
            }
        }

        _vesting[beneficiary_].push(Vesting(beneficiary_, releaseTime_, tokenAmount_));
        emit VestingLockedIn(beneficiary_, releaseTime_, tokenAmount_);
        return;
    }

    /**
     * @return the address of the token being stored.
     */
    function token() public view override returns (IERC20) {
        return _token;
    }

    /**
     * @return the vesting for an address
     * @param beneficiary_ the address for which the vesting is returned
     */
    function vestingFor(address beneficiary_) public view override returns (Vesting[] memory) {
        return _vesting[beneficiary_];
    }

    /**
     * @dev releases the tokens of the msg sender
     */
    function release() public override {
        Vesting[] memory vestings = _vesting[_msgSender()];
        uint256 tokensToRelease = 0;
        for (uint256 i = 0; i < vestings.length; i++) {
            if (vestings[i].releaseTime <= block.timestamp) {
                tokensToRelease = tokensToRelease + vestings[i].tokenAmount;
                emit VestingReleased(_msgSender(), vestings[i].releaseTime, vestings[i].tokenAmount);
                _vesting[_msgSender()][i].tokenAmount = 0;
            }
        }
        require(tokensToRelease > 0, "VestingVault: Cannot release 0 tokens");

        bool success = token().transfer(_msgSender(), tokensToRelease);
        require(success, "Token transfer unsuccessful");
    }
}
