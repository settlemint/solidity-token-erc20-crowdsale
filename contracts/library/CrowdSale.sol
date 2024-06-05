// SPDX-License-Identifier: MIT
// SettleMint.com

pragma solidity ^0.8.17;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";
import {VestingVault} from "./VestingVault.sol";
import {ICrowdSale} from "./ICrowdSale.sol";

/**
 * @title CrowdSale
 */
contract CrowdSale is
    Context,
    ERC165,
    Pausable,
    AccessControl,
    ReentrancyGuard,
    ICrowdSale
{
    bytes32 public constant WHITELISTED_ROLE = keccak256("WHITELISTED_ROLE");

    // The token being sold
    IERC20 private _token;

    // The price feed for conversion rates from Matic to USD
    // Learn more: https://docs.chain.link/docs/matic-addresses/
    AggregatorV3Interface internal priceFeed;

    // Number of tokens for one USD
    uint256 private _usdRate;

    // Address where funds are collected
    address payable private _wallet;

    // Amount of wei raised
    uint256 private _fundsRaised;

    // vesting end date
    uint256 private _vestingEndDate;

    // vesting vault
    VestingVault private _vestingVault;

    struct Vesting {
        uint256 amount;
        uint256 cliff;
    }

    // Mapping of addresses to Vestings
    mapping(address => Vesting) private _vested;

    constructor(
        address priceFeed_,
        address token_,
        address payable wallet_,
        uint256 usdRate_,
        uint256 vestingEndDate_,
        address vestingVault_
    ) {
        require(wallet_ != address(0), "Crowdsale: wallet is the zero address");
        require(token_ != address(0), "Crowdsale: token is the zero address");

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        priceFeed = AggregatorV3Interface(priceFeed_);
        _token = IERC20(token_);
        _wallet = wallet_;
        _usdRate = usdRate_;
        _vestingEndDate = vestingEndDate_;
        _vestingVault = VestingVault(vestingVault_);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, AccessControl) returns (bool) {
        return
            interfaceId == type(ICrowdSale).interfaceId ||
            interfaceId == type(Pausable).interfaceId ||
            super.supportsInterface(interfaceId); // ERC165, AccessControl
    }

    /**
     * @dev executed on a call to the contract if none of the other functions match the given function signature,
     * or if no data was supplied at all and there is no receive Ether function
     * Note that other contracts will transfer funds with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
     * Learn more: https://docs.soliditylang.org/en/latest/contracts.html#fallback-function
     */
    fallback() external payable {
        buyTokens(_msgSender());
    }

    /**
     * @dev is executed on a call to the contract with empty calldata
     * Note that other contracts will transfer funds with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
     * Learn more: https://docs.soliditylang.org/en/latest/contracts.html#receive-ether-function
     */
    receive() external payable {
        buyTokens(_msgSender());
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     * - The sender of the transaction must have the DEFAULT_ADMIN_ROLE
     */
    function pause() public whenNotPaused {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     * - The sender of the transaction must have the DEFAULT_ADMIN_ROLE
     */
    function unpause() public whenPaused {
        _unpause();
    }

    /**
     * @return the address of the token being sold.
     */
    function token() public view override returns (IERC20) {
        return _token;
    }

    /**
     * @return the address where funds are collected.
     */
    function wallet() public view override returns (address payable) {
        return _wallet;
    }

    /**
     * @return the amount of funds raised.
     */
    function fundsRaised() public view override returns (uint256) {
        return _fundsRaised;
    }

    /**
     * @return the amount tokens available to the crowdsale for selling.
     */
    function tokensAvailable() public view override returns (uint256) {
        return token().balanceOf(address(this));
    }

    /**
     * @dev utility function to allow the owner to handle private and bitcoin buyers
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param tokenAmount Number of tokens to be purchased
     * @param beneficiary Recipient of the token purchase
     */
    function externalBuyTokens(
        address beneficiary,
        uint256 tokenAmount
    ) public override nonReentrant whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 weiAmount = getWeiAmount(tokenAmount);
        preValidatePurchase(beneficiary, weiAmount);
        _fundsRaised += weiAmount;
        processPurchase(beneficiary, tokenAmount);
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokenAmount);
        updatePurchasingState(beneficiary, weiAmount);
        postValidatePurchase(beneficiary, weiAmount);
    }

    /**
     * @dev low level token purchase
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param beneficiary Recipient of the token purchase
     */
    function buyTokens(
        address beneficiary
    )
        public
        payable
        override
        nonReentrant
        whenNotPaused
        onlyRole(WHITELISTED_ROLE)
    {
        uint256 weiAmount = msg.value;
        preValidatePurchase(beneficiary, weiAmount);

        uint256 tokenAmount = getTokenAmount(weiAmount);

        _fundsRaised += weiAmount;
        processPurchase(beneficiary, tokenAmount);
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokenAmount);
        updatePurchasingState(beneficiary, weiAmount);
        forwardFunds();
        postValidatePurchase(beneficiary, weiAmount);
    }

    /**
     * @dev Validates beneficiary and weiAmount before executing purchase
     */
    function preValidatePurchase(
        address beneficiary,
        uint256 weiAmount
    ) internal view {
        require(
            beneficiary != address(0),
            "Crowdsale: beneficiary is the zero address"
        );
        require(weiAmount != 0, "Crowdsale: amount is 0");
        this; // silence state mutability warning without generating bytecode - see
        // https://github.com/ethereum/solidity/issues/2691
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Doesn't necessarily emit/send
     * tokens.
     * @param beneficiary Address receiving the tokens
     * @param tokenAmount Number of tokens to be purchased
     */
    function processPurchase(
        address beneficiary,
        uint256 tokenAmount
    ) internal {
        if (_vestingEndDate > 0) {
            _vestingVault.addBeneficiary(
                beneficiary,
                _vestingEndDate,
                tokenAmount
            );
            deliverTokens(address(_vestingVault), tokenAmount);
        } else {
            deliverTokens(beneficiary, tokenAmount);
        }
    }

    /**
     * @dev Transfer of tokens from crowdsale to beneficiary. Override this method to modify the way in which the
     * crowdsale ultimately gets and sends its tokens.
     * @param beneficiary Address performing the token purchase
     * @param tokenAmount Number of tokens to be transferred
     */
    function deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        _token.transfer(beneficiary, tokenAmount);
    }

    /**
     * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid
     * conditions are not met.
     * @param beneficiary Address performing the token purchase
     * @param weiAmount Value in wei involved in the purchase
     */
    function postValidatePurchase(
        address beneficiary,
        uint256 weiAmount
    ) internal view {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Override for extensions that require an internal state to check for validity (current user contributions,
     * etc.)
     * @param beneficiary Address receiving the tokens
     * @param weiAmount Value in wei involved in the purchase
     */
    function updatePurchasingState(
        address beneficiary,
        uint256 weiAmount
    ) internal {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Converts the weiAmount into equivalent number of tokens
     * @param weiAmount Value of wei for conversion
     */
    function getTokenAmount(uint256 weiAmount) public view returns (uint256) {
        if (address(priceFeed) != address(0)) {
            (, int256 price, , , ) = priceFeed.latestRoundData();
            return ((weiAmount * uint256(price)) * _usdRate) / 10 ** 8;
        }
        return ((weiAmount * 10) * _usdRate); // fixed rate of 10 USD per ETH
    }

    /**
     * @dev Converts the tokenAmount into equivalent number of wei
     * @param tokenAmount Number of tokens for convertion
     */
    function getWeiAmount(uint256 tokenAmount) public view returns (uint256) {
        if (address(priceFeed) != address(0)) {
            (, int256 price, , , ) = priceFeed.latestRoundData();
            return (tokenAmount * 10 ** 8) / (uint256(price) * _usdRate);
        }
        return (((tokenAmount) / 10) * _usdRate); // fixed rate of 10 USD per ETH
    }

    /**
     * @dev Determines how ETH is stored/forwarded on purchases.
     */
    function forwardFunds() internal {
        _wallet.transfer(msg.value);
    }
}
