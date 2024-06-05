// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../contracts/library/CrowdSale.sol";
import "../contracts/ExampleToken.sol";
import "../contracts/library/VestingVault.sol";
import "../contracts/library/AggregatorV3Interface.sol";
import "../contracts/MockAggregatorV3.sol";

contract CrowdSaleTest is Test {
    CrowdSale public crowdSale;
    ExampleToken public token;
    VestingVault public vestingVault;
    MockAggregatorV3 public priceFeed;
    address payable public wallet = payable(address(0x123));
    uint256 public usdRate = 100; // 1 USD = 100 tokens
    uint256 public vestingEndDate = block.timestamp + 365 days;
    address public admin = address(0x1);
    address public whitelisted = address(0x2);

    bytes32 public constant VAULT_CONTROLLER_ROLE =
        keccak256("VAULT_CONTROLLER_ROLE");

    function setUp() public {
        priceFeed = new MockAggregatorV3();
        token = new ExampleToken(
            "Test Token",
            "TTK",
            1000000 * 10 ** 18,
            address(this)
        );
        vestingVault = new VestingVault(IERC20(address(token)));
        crowdSale = new CrowdSale(
            address(priceFeed),
            address(token),
            wallet,
            usdRate,
            vestingEndDate,
            address(vestingVault)
        );

        token.transfer(address(crowdSale), 1000000 * 10 ** 18); // Transfer tokens to the crowdsale contract

        crowdSale.grantRole(crowdSale.DEFAULT_ADMIN_ROLE(), admin);
        crowdSale.grantRole(crowdSale.WHITELISTED_ROLE(), whitelisted);

        // Set initial price data in the mock
        priceFeed.setLatestRoundData(
            1,
            2000 * 10 ** 8,
            block.timestamp,
            block.timestamp,
            1
        );

        // Grant the VAULT_CONTROLLER_ROLE to the CrowdSale contract in the VestingVault
        vestingVault.grantRole(VAULT_CONTROLLER_ROLE, address(crowdSale));
    }

    function testInitialization() public {
        assertEq(crowdSale.wallet(), wallet);
        assertEq(address(crowdSale.token()), address(token));
        assertEq(crowdSale.fundsRaised(), 0);
    }

    function testBuyTokens() public {
        uint256 buyAmount = 1 ether;

        vm.deal(whitelisted, 2 ether); // Provide enough ether to the whitelisted account
        vm.prank(whitelisted);
        crowdSale.buyTokens{value: buyAmount}(whitelisted);

        uint256 tokenAmount = crowdSale.getTokenAmount(buyAmount);
        assertEq(crowdSale.fundsRaised(), buyAmount);
    }

    function testExternalBuyTokens() public {
        uint256 tokenAmount = 1000 * 10 ** 18;

        vm.prank(admin);
        crowdSale.externalBuyTokens(admin, tokenAmount);

        assertEq(crowdSale.fundsRaised(), crowdSale.getWeiAmount(tokenAmount));
    }

    function testBuyTokensRevertWithoutWhitelist() public {
        uint256 buyAmount = 1 ether;

        vm.expectRevert();
        vm.prank(address(0x3));
        crowdSale.buyTokens{value: buyAmount}(address(0x3));
    }

    function testExternalBuyTokensRevertWithoutAdmin() public {
        uint256 tokenAmount = 1000 * 10 ** 18;

        vm.expectRevert();
        vm.prank(address(0x4));
        crowdSale.externalBuyTokens(address(0x4), tokenAmount);
    }

    function testPause() public {
        vm.prank(admin);
        crowdSale.pause();

        assertTrue(crowdSale.paused());
    }

    function testUnpause() public {
        vm.prank(admin);
        crowdSale.pause();
        assertTrue(crowdSale.paused());

        vm.prank(admin);
        crowdSale.unpause();
        assertFalse(crowdSale.paused());
    }

    function testBuyTokensWhilePaused() public {
        uint256 buyAmount = 1 ether;

        vm.prank(admin);
        crowdSale.pause();

        vm.expectRevert();
        vm.prank(whitelisted);
        crowdSale.buyTokens{value: buyAmount}(whitelisted);
    }

    function testSupportsInterface() public {
        assertTrue(crowdSale.supportsInterface(type(ICrowdSale).interfaceId));
        assertTrue(crowdSale.supportsInterface(type(Pausable).interfaceId));
    }

    function testMockAggregator() public {
        assertEq(priceFeed.decimals(), 8);
        assertEq(priceFeed.description(), "Mock Aggregator");
        assertEq(priceFeed.version(), 1);
    }
}
