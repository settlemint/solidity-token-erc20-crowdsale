// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../src/ExampleToken.sol";
import "../src/ExampleCrowdSale.sol";
import "../src/ExampleVestingVault.sol";
import "../src/library/IVestingVault.sol";

contract ExampleCrowdSaleTest is Test {
    ExampleToken private token;
    ExampleVestingVault private vestingVault;
    ExampleCrowdSale private crowdSale;
    address private adminUser;
    address private userOne;
    address private userTwo;
    address private userThree;
    address private wallet;
    uint256 private constant initialSupply = 3765000000 * 10 ** 18;
    uint256 private releaseTime;
    uint256 private constant tokenAmount = 1;
    uint256 private constant increaseExampleTokensBy = 5;
    uint256 private newExampleTokenAmount;

    function setUp() public {
        adminUser = address(this);
        wallet = address(0x1001);
        userOne = address(0x1002);
        userTwo = address(0x1003);
        userThree = address(0x1004);
        releaseTime = block.timestamp + 30 * 30 days;
        newExampleTokenAmount = tokenAmount + increaseExampleTokensBy;

        // Step 1: Deploy ExampleToken
        token = new ExampleToken("ExampleToken", "ET", initialSupply, wallet);

        // Step 2: Deploy ExampleVestingVault
        vestingVault = new ExampleVestingVault(IERC20(address(token)));

        // Simulate a price feed address for the sake of the test
        address priceFeed = address(0x1234);

        // Step 3: Deploy ExampleCrowdSale
        crowdSale = new ExampleCrowdSale(
            priceFeed,
            address(token),
            payable(wallet),
            250, // USD rate
            releaseTime,
            address(vestingVault)
        );
        vm.startPrank(wallet);
        token.transfer(wallet, initialSupply);
        vm.stopPrank();
    }

    function testHasToken() public {
        assertEq(address(vestingVault.token()), address(token));
    }

    function testCannotAddBeneficiaryIfNotVaultController() public {
        vm.expectRevert();
        vestingVault.addBeneficiary(userOne, releaseTime, tokenAmount);
    }

    function testCannotGrantVaultControllerRoleIfNotAdmin() public {
        bytes32 role = vestingVault.VAULT_CONTROLLER_ROLE();
        vm.startPrank(userOne);
        vm.expectRevert();
        vestingVault.grantRole(role, address(crowdSale));
        vm.stopPrank();
    }

    function testCanGrantVaultControllerRoleIfAdmin() public {
        bytes32 role = vestingVault.VAULT_CONTROLLER_ROLE();
        vestingVault.grantRole(role, adminUser);
        assertTrue(vestingVault.hasRole(role, adminUser));
    }

    function testAddNewBeneficiaryToVestingVault() public {
        vestingVault.grantRole(vestingVault.VAULT_CONTROLLER_ROLE(), adminUser);
        vm.expectEmit(true, true, true, true);
        emit IVestingVault.VestingLockedIn(userOne, releaseTime, tokenAmount);
        vestingVault.addBeneficiary(userOne, releaseTime, tokenAmount);
        vm.startPrank(wallet);
        token.transfer(address(vestingVault), tokenAmount);
        IVestingVault.Vesting[] memory vestings = vestingVault.vestingFor(
            userOne
        );
        uint256 totalExampleTokenAmount = 0;
        for (uint256 i = 0; i < vestings.length; i++) {
            totalExampleTokenAmount += vestings[i].tokenAmount;
        }

        // Assertions
        assertEq(totalExampleTokenAmount, tokenAmount);
        assertEq(token.balanceOf(address(vestingVault)), tokenAmount);
        vm.stopPrank();
    }

    function testIncreaseTokensForExistingBeneficiary() public {
        vestingVault.grantRole(vestingVault.VAULT_CONTROLLER_ROLE(), adminUser);
        vestingVault.addBeneficiary(userOne, releaseTime, tokenAmount);
        vm.prank(wallet);
        token.transfer(address(vestingVault), tokenAmount);

        vestingVault.addBeneficiary(
            userOne,
            releaseTime,
            increaseExampleTokensBy
        );
        vm.prank(wallet);
        token.transfer(address(vestingVault), increaseExampleTokensBy);

        IVestingVault.Vesting[] memory vestings = vestingVault.vestingFor(
            userOne
        );
        uint256 totalExampleTokenAmount;
        for (uint256 i = 0; i < vestings.length; i++) {
            totalExampleTokenAmount += vestings[i].tokenAmount;
        }

        assertEq(totalExampleTokenAmount, newExampleTokenAmount);
        assertEq(token.balanceOf(address(vestingVault)), newExampleTokenAmount);
        vm.stopPrank();
    }

    function testAddAnotherVestingForDifferentReleaseTime() public {
        vestingVault.grantRole(vestingVault.VAULT_CONTROLLER_ROLE(), adminUser);
        vm.startPrank(adminUser);

        vm.expectEmit(true, true, true, true);
        emit IVestingVault.VestingLockedIn(userOne, releaseTime, tokenAmount);
        vestingVault.addBeneficiary(userOne, releaseTime, tokenAmount);

        vm.expectEmit(true, true, true, true);
        emit IVestingVault.VestingLockedIn(
            userOne,
            releaseTime + 1,
            tokenAmount
        );
        vestingVault.addBeneficiary(userOne, releaseTime + 1, tokenAmount);

        vm.stopPrank();
    }

    function testReturnVestingOfBeneficiary() public {
        vestingVault.grantRole(vestingVault.VAULT_CONTROLLER_ROLE(), adminUser);
        vestingVault.addBeneficiary(userOne, releaseTime, tokenAmount);
        vm.prank(wallet);
        token.transfer(address(vestingVault), tokenAmount);

        IVestingVault.Vesting[] memory vestings = vestingVault.vestingFor(
            userOne
        );
        assertEq(vestings[0].beneficiary, userOne);
    }

    function testReleaseVestingTokensOfBeneficiary() public {
        vestingVault.grantRole(vestingVault.VAULT_CONTROLLER_ROLE(), adminUser);
        vestingVault.addBeneficiary(userOne, releaseTime, tokenAmount);
        vm.prank(wallet);
        token.transfer(address(vestingVault), tokenAmount);

        vm.warp(releaseTime + 1);
        vm.prank(userOne);
        vestingVault.release();

        assertEq(token.balanceOf(userOne), tokenAmount);
        assertEq(token.balanceOf(address(vestingVault)), 0);
    }

    function testFailToReleaseTokensWithLessThanOneToken() public {
        vestingVault.grantRole(vestingVault.VAULT_CONTROLLER_ROLE(), adminUser);

        vm.warp(releaseTime + 1);

        vm.startPrank(userThree);
        vm.expectRevert(" VestingVault: Cannot release 0 tokens");
        vestingVault.release();

        vm.stopPrank();
    }

    function testFailToReleaseTokensBeforeReleaseTime() public {
        vestingVault.grantRole(vestingVault.VAULT_CONTROLLER_ROLE(), adminUser);
        uint256 veryLargeReleaseTime = 3114690041;

        vestingVault.addBeneficiary(userTwo, veryLargeReleaseTime, tokenAmount);
        token.transfer(address(vestingVault), tokenAmount);

        vm.expectRevert("VestingVault: Cannot release 0 tokens");
        vestingVault.release();
    }

    function testMultipleReleaseTimes() public {
        vestingVault.grantRole(vestingVault.VAULT_CONTROLLER_ROLE(), adminUser);
        vestingVault.addBeneficiary(userTwo, releaseTime, tokenAmount);
        vm.prank(wallet);
        token.transfer(address(vestingVault), tokenAmount);

        vm.warp(releaseTime + 1);
        vm.prank(userTwo);
        vestingVault.release();

        assertEq(token.balanceOf(userTwo), tokenAmount);
        assertEq(token.balanceOf(address(vestingVault)), 0);
    }

    function testUserCannotReleaseTokensNotBelongingToHim() public {
        vestingVault.grantRole(vestingVault.VAULT_CONTROLLER_ROLE(), adminUser);
        vestingVault.addBeneficiary(userThree, releaseTime, tokenAmount);
        vm.prank(wallet);
        token.transfer(address(vestingVault), tokenAmount);

        vm.warp(releaseTime + 1);
        vm.prank(userOne);
        vm.expectRevert("VestingVault: Cannot release 0 tokens");
        vestingVault.release();
    }

    function testSupportsERC165Interface() public {
        bytes4 ERC165InterfaceId = 0x01ffc9a7;
        assertTrue(vestingVault.supportsInterface(ERC165InterfaceId));
    }
}
