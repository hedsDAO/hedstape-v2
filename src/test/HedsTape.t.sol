// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../HedsTape.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "./lib/PRBMath.sol";

interface CheatCodes {
  function prank(address) external;
  function expectRevert(bytes4) external;
  function expectRevert(bytes memory) external;
  function warp(uint256) external;
}

contract HedsTapeTest is IERC721Receiver, DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    HedsTape hedsTape;

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns(bytes4) {
        return this.onERC721Received.selector;
    }

    function setUp() public {
        hedsTape = new HedsTape();
    }

    address[] addresses;
    uint64[] shares;
    address[] whitelistAddresses;
    uint[] mints;

    function _seedWithdrawalData() internal {
        addresses.push(address(1));
        addresses.push(address(2));
        addresses.push(address(3));
        addresses.push(address(4));
        shares.push(1000);
        shares.push(2000);
        shares.push(3000);
        shares.push(4000);

        hedsTape.seedWithdrawalData(addresses, shares);
    }

    function _beginSale() internal {
        hedsTape.updateStartTime(1650000000);
        cheats.warp(1650000000);
    }

    function _beginWhitelistSale() internal {
        hedsTape.updateWhitelistStartTime(1650000000);
        cheats.warp(1650000000);
    }

    function testUpdateStartTimeAsOwner() public {
        hedsTape.updateStartTime(1650000000);
        (, , uint32 newStartTime, ) = hedsTape.saleConfig();

        assertEq(newStartTime, 1650000000);
    }

    function testUpdateStartTimeAsNotOwner() public {
        cheats.expectRevert(bytes("Ownable: caller is not the owner"));
        cheats.prank(address(0));
        hedsTape.updateStartTime(1650000000);
    }

    function testCannotMintHeadBeforeStartTime() public {
        hedsTape.updateStartTime(1650000000);
        cheats.warp(1649999999);
        (uint64 price, , ,) = hedsTape.saleConfig();
        cheats.expectRevert(abi.encodeWithSignature("BeforeSaleStart()"));
        hedsTape.mintHead{value: price}(1);
    }

    function testCannotMintHeadInsufficientFunds() public {
        _beginSale();
        (uint64 price, , ,) = hedsTape.saleConfig();
        cheats.expectRevert(abi.encodeWithSignature("InsufficientFunds()"));
        hedsTape.mintHead{value: price - 1}(1);
    }

    function testCannotMintHeadsBeyondMaxSupply() public {
        _beginSale();
        (uint64 price, uint32 maxSupply, ,) = hedsTape.saleConfig();
        uint valueToSend = uint(price) * uint(maxSupply + 1);
        cheats.expectRevert(abi.encodeWithSignature("ExceedsMaxSupply()"));
        hedsTape.mintHead{value: valueToSend}(maxSupply + 1);
    }

    function testMintHead() public {
        _beginSale();
        (uint64 price, , ,) = hedsTape.saleConfig();
        hedsTape.mintHead{value: price}(1);
    }

    function testMintHeads(uint16 amount) public {
        (uint64 price, uint32 maxSupply, ,) = hedsTape.saleConfig();
        if (amount > maxSupply) amount = uint16(maxSupply);
        if (amount == 0) amount = 1;

        _beginSale();

        uint valueToSend = uint(price) * uint(amount);

        hedsTape.mintHead{value: valueToSend}(amount);
    }

    function testMintHeadsUpToMaxSupply() public {
        _beginSale();
        (uint64 price, uint32 maxSupply, ,) = hedsTape.saleConfig();
        uint valueToSend = uint(price) * uint(maxSupply);
        hedsTape.mintHead{value: valueToSend}(maxSupply);
    }

    function testTokenURI() public {
        hedsTape.setBaseUri("ipfs://sup");

        _beginSale();
        (uint64 price, uint32 maxSupply, ,) = hedsTape.saleConfig();
        uint valueToSend = uint(price) * uint(maxSupply);
        hedsTape.mintHead{value: valueToSend}(maxSupply);

        string memory uri = hedsTape.tokenURI(1);
        assertEq(uri, "ipfs://sup");
    }

    function testSetBaseUriNotOwner() public {
        cheats.expectRevert(bytes("Ownable: caller is not the owner"));
        cheats.prank(address(1));
        hedsTape.setBaseUri("ipfs://sup");
    }

    function testWithdraw() public {
        _beginSale();
        (uint64 price, uint32 maxSupply, ,) = hedsTape.saleConfig();
        uint amount = uint(price) * uint(maxSupply);
        hedsTape.mintHead{value: amount}(maxSupply);

        assertEq(address(hedsTape).balance, amount);

        uint balanceBefore = address(this).balance;
        hedsTape.withdraw();
        uint balanceAfter = address(this).balance;

        assertEq(balanceAfter - balanceBefore, amount);
    }

    function testWithdrawNotOwner() public {
        cheats.expectRevert(bytes("Ownable: caller is not the owner"));
        cheats.prank(address(1));
        hedsTape.withdraw();
    }

    function testSeedWithdrawalData() public {
        _seedWithdrawalData();

        (uint64 shareBps1, uint64 amtWithdrawn1) = hedsTape.withdrawalData(address(1));
        (uint64 shareBps2, uint64 amtWithdrawn2) = hedsTape.withdrawalData(address(2));
        (uint64 shareBps3, uint64 amtWithdrawn3) = hedsTape.withdrawalData(address(3));
        (uint64 shareBps4, uint64 amtWithdrawn4) = hedsTape.withdrawalData(address(4));

        assertEq(shareBps1, 1000);
        assertEq(amtWithdrawn1, 0);
        assertEq(shareBps2, 2000);
        assertEq(amtWithdrawn2, 0);
        assertEq(shareBps3, 3000);
        assertEq(amtWithdrawn3, 0);
        assertEq(shareBps4, 4000);
        assertEq(amtWithdrawn4, 0);
    }

    function testCannotSeedWithdrawalDataTooManyShares() public {
        addresses.push(address(1));
        addresses.push(address(2));
        addresses.push(address(3));
        addresses.push(address(4));
        shares.push(1000);
        shares.push(2000);
        shares.push(3000);
        shares.push(4001);

        cheats.expectRevert(abi.encodeWithSignature("InvalidShareQuantity()"));
        hedsTape.seedWithdrawalData(addresses, shares);
    }

    function testCannotSeedWithdrawalDataTooFewShares() public {
        addresses.push(address(1));
        addresses.push(address(2));
        addresses.push(address(3));
        addresses.push(address(4));
        shares.push(1000);
        shares.push(2000);
        shares.push(3000);
        shares.push(3999);

        cheats.expectRevert(abi.encodeWithSignature("InvalidShareQuantity()"));
        hedsTape.seedWithdrawalData(addresses, shares);
    }

    function testCannotSeedWithdrawalDataNotOwner() public {
        cheats.prank(address(1));

        cheats.expectRevert(bytes("Ownable: caller is not the owner"));
        _seedWithdrawalData();
    }

    function testWithdrawShare() public {
        _seedWithdrawalData();

        _beginSale();
        (uint64 price, , ,) = hedsTape.saleConfig();
        uint amount = 3;
        uint valueToSend = uint(price) * amount;
        hedsTape.mintHead{value: valueToSend}(amount);

        cheats.prank(address(1));
        uint balanceBefore = address(1).balance;
        hedsTape.withdrawShare();
        uint balanceAfter = address(1).balance;
        assertEq(balanceAfter - balanceBefore, valueToSend / 10);
    }

    function testWithdrawShare(uint16 amount) public {
        _seedWithdrawalData();

        _beginSale();
        (uint64 price, uint32 maxSupply, ,) = hedsTape.saleConfig();
        uint amountToMint = uint(amount);
        if (amountToMint == 0) amountToMint = 1;
        if (amountToMint > maxSupply) amountToMint = uint(maxSupply);
        uint valueToSend = uint(price) * amountToMint;
        hedsTape.mintHead{value: valueToSend}(amountToMint);

        cheats.prank(address(1));
        uint balanceBefore = address(1).balance;
        hedsTape.withdrawShare();
        uint balanceAfter = address(1).balance;
        assertEq(balanceAfter - balanceBefore, valueToSend / 10);
    }

    function testWithdrawShares(uint16 share, uint16 amount) public {
        (uint64 price, uint32 maxSupply, ,) = hedsTape.saleConfig();

        if (amount == 0) amount = 1;
        if (amount > maxSupply) amount = uint16(maxSupply);
        if (share == 0) share = 1;
        uint firstShare = PRBMath.mulDiv(uint(share), 10000, type(uint16).max);
        if (firstShare < 1) firstShare = 1;
        uint secondShare = (10000 - firstShare) / 3;
        uint thirdShare = 10000 - firstShare - secondShare;

        addresses.push(address(1));
        addresses.push(address(2));
        addresses.push(address(3));
        shares.push(uint64(firstShare));
        shares.push(uint64(secondShare));
        shares.push(uint64(thirdShare));
        hedsTape.seedWithdrawalData(addresses, shares);

        _beginSale();

        uint valueToSend = uint(price) * uint(amount);

        hedsTape.mintHead{value: valueToSend}(amount);

        uint price256 = uint(price);
        uint amount256 = uint(amount);

        cheats.prank(address(1));
        uint balanceBefore1 = address(1).balance;
        hedsTape.withdrawShare();
        uint balanceAfter1 = address(1).balance;
        uint expected1 = uint(firstShare) * price256 * amount256 / 10000;
        assertEq(balanceAfter1 - balanceBefore1, expected1);

        if (secondShare != 0) {
            cheats.prank(address(2));
            uint balanceBefore2 = address(2).balance;
            hedsTape.withdrawShare();
            uint balanceAfter2 = address(2).balance;
            uint expected2 = uint(secondShare) * price256 * amount256 / 10000;
            assertEq(balanceAfter2 - balanceBefore2, expected2);
        }

        if (thirdShare != 0) {
            cheats.prank(address(3));
            uint balanceBefore3 = address(3).balance;
            hedsTape.withdrawShare();
            uint balanceAfter3 = address(3).balance;
            uint expected3 = uint(thirdShare) * price256 * amount256 / 10000;
            assertEq(balanceAfter3 - balanceBefore3, expected3);
        }
    }

    function testCannotWithdrawShareUnauthorized() public {
        _seedWithdrawalData();

        _beginSale();
        (uint64 price, , ,) = hedsTape.saleConfig();
        uint amount = 3;
        uint valueToSend = uint(price) * amount;
        hedsTape.mintHead{value: valueToSend}(amount);

        cheats.prank(address(5));
        cheats.expectRevert(abi.encodeWithSignature("NoShares()"));
        hedsTape.withdrawShare();
    }

    function testCannotWithdrawExcessiveShare() public {
        _seedWithdrawalData();

        _beginSale();
        (uint64 price, , ,) = hedsTape.saleConfig();
        uint amount = 3;
        uint valueToSend = uint(price) * amount;
        hedsTape.mintHead{value: valueToSend}(amount);

        uint balanceBefore = address(1).balance;
        cheats.prank(address(1));
        hedsTape.withdrawShare();
        cheats.prank(address(1));
        hedsTape.withdrawShare();
        cheats.prank(address(1));
        hedsTape.withdrawShare();
        uint balanceAfter = address(1).balance;
        assertEq(balanceAfter - balanceBefore, valueToSend / 10);
    }

    function testWithdrawAllShares() public {
        _seedWithdrawalData();

        _beginSale();
        (uint64 price, , ,) = hedsTape.saleConfig();
        uint amount = 3;
        uint valueToSend = uint(price) * amount;
        hedsTape.mintHead{value: valueToSend}(amount);

        cheats.prank(address(1));
        uint balanceBefore1 = address(1).balance;
        hedsTape.withdrawShare();
        uint balanceAfter1 = address(1).balance;
        assertEq(balanceAfter1 - balanceBefore1, valueToSend / 10);

        cheats.prank(address(2));
        uint balanceBefore2 = address(2).balance;
        hedsTape.withdrawShare();
        uint balanceAfter2 = address(2).balance;
        assertEq(balanceAfter2 - balanceBefore2, valueToSend / 10 * 2);

        cheats.prank(address(3));
        uint balanceBefore3 = address(3).balance;
        hedsTape.withdrawShare();
        uint balanceAfter3 = address(3).balance;
        assertEq(balanceAfter3 - balanceBefore3, valueToSend / 10 * 3);

        cheats.prank(address(4));
        uint balanceBefore4 = address(4).balance;
        hedsTape.withdrawShare();
        uint balanceAfter4 = address(4).balance;
        assertEq(balanceAfter4 - balanceBefore4, valueToSend / 10 * 4);
    }

    function testWithdrawMultipleTimes() public {
        _seedWithdrawalData();

        _beginSale();
        (uint64 price, , ,) = hedsTape.saleConfig();
        uint amount = 3;
        uint valueToSend = uint(price) * amount;
        hedsTape.mintHead{value: valueToSend}(amount);

        cheats.prank(address(1));
        uint balanceBefore = address(1).balance;
        hedsTape.withdrawShare();
        uint balanceAfter = address(1).balance;
        assertEq(balanceAfter - balanceBefore, valueToSend / 10);

        uint amount2 = 5;
        uint valueToSend2 = uint(price) * amount2;
        hedsTape.mintHead{value: valueToSend2}(amount2);

        cheats.prank(address(1));
        uint balanceBefore1 = address(1).balance;
        hedsTape.withdrawShare();
        uint balanceAfter1 = address(1).balance;
        assertEq(balanceAfter1 - balanceBefore1, valueToSend2 / 10);

        uint amount3 = 77;
        uint valueToSend3 = uint(price) * amount3;
        hedsTape.mintHead{value: valueToSend3}(amount3);

        cheats.prank(address(1));
        uint balanceBefore2 = address(1).balance;
        hedsTape.withdrawShare();
        uint balanceAfter2 = address(1).balance;
        assertEq(balanceAfter2 - balanceBefore2, valueToSend3 / 10);
    }

    function testCannotNonWhitelistedMint() public {
        _beginWhitelistSale();
        (uint64 price, , ,) = hedsTape.saleConfig();
        cheats.expectRevert(abi.encodeWithSignature("ExceedsWhitelistAllowance()"));
        hedsTape.whitelistMintHead{value: price}(1);
    }

    function testSeedWhitelist() public {
        whitelistAddresses.push(address(1));
        whitelistAddresses.push(address(2));
        whitelistAddresses.push(address(3));
        mints.push(5);
        mints.push(10);
        mints.push(15);
        hedsTape.seedWhitelist(whitelistAddresses, mints);
        uint availableMints1 = hedsTape.whitelist(address(1));
        assertEq(availableMints1, 5);
        uint availableMints2 = hedsTape.whitelist(address(2));
        assertEq(availableMints2, 10);
        uint availableMints3 = hedsTape.whitelist(address(3));
        assertEq(availableMints3, 15);
    }

    function testCannotExcessiveWhitelistMint() public {
        _beginWhitelistSale();
        whitelistAddresses.push(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);
        mints.push(5);
        hedsTape.seedWhitelist(whitelistAddresses, mints);
        (uint64 price, , ,) = hedsTape.saleConfig();
        uint amount = uint(price) * 6;
        cheats.expectRevert(abi.encodeWithSignature("ExceedsWhitelistAllowance()"));
        hedsTape.whitelistMintHead{value: amount}(6);
    }

    function testCannotWhitelistMintHeadBeforeStartTime() public {
        hedsTape.updateWhitelistStartTime(1650000000);
        cheats.warp(1649999999);
        whitelistAddresses.push(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);
        mints.push(5);
        hedsTape.seedWhitelist(whitelistAddresses, mints);
        (uint64 price, , ,) = hedsTape.saleConfig();
        cheats.expectRevert(abi.encodeWithSignature("BeforeSaleStart()"));
        hedsTape.whitelistMintHead{value: price}(1);
    }

    function testWhitelistMint() public {
        _beginWhitelistSale();
        whitelistAddresses.push(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);
        mints.push(5);
        hedsTape.seedWhitelist(whitelistAddresses, mints);
        (uint64 price, , ,) = hedsTape.saleConfig();
        uint amount = uint(price) * 5;
        hedsTape.whitelistMintHead{value: amount}(5);
    }

    fallback() external payable {}
    receive() external payable {}
}
