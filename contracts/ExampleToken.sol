// SPDX-License-Identifier: FSL-1.1-MIT
// SettleMint.com

pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract ExampleToken is ERC165, ERC20, AccessControl {
    constructor(string memory name_, string memory symbol_, uint256 supply_, address wallet_) ERC20(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        // We will mint all tokens in one go, and send them to a wallet
        _mint(wallet_, supply_);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId); // ERC165, AccessControl
    }
}
