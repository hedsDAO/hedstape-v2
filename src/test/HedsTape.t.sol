// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../HedsTape.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

interface CheatCodes {
  function prank(address) external;
  function expectRevert(bytes calldata) external;
  function expectRevert(bytes4) external;
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

    function testFailMintHeadBeforeStartTime() public {
        hedsTape.updateStartTime(1650000000);
        cheats.warp(1649999999);
        (uint64 price, , ,) = hedsTape.saleConfig();
        hedsTape.mintHead{value: price}(1);
    }

    function testFailMintHeadInsufficientFunds() public {
        _beginSale();
        (uint64 price, , ,) = hedsTape.saleConfig();
        hedsTape.mintHead{value: price - 1}(1);
    }

    function testFailMintHeadsBeyondMaxSupply() public {
        _beginSale();
        (uint64 price, uint32 maxSupply, ,) = hedsTape.saleConfig();
        uint valueToSend = uint(price) * uint(maxSupply + 1);
        hedsTape.mintHead{value: valueToSend}(maxSupply + 1);
    }

    function testMintHead() public {
        _beginSale();
        (uint64 price, , ,) = hedsTape.saleConfig();
        hedsTape.mintHead{value: price}(1);
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

    function testFailSeedWithdrawalDataTooManyShares() public {
        addresses.push(address(1));
        addresses.push(address(2));
        addresses.push(address(3));
        addresses.push(address(4));
        shares.push(1000);
        shares.push(2000);
        shares.push(3000);
        shares.push(4001);

        hedsTape.seedWithdrawalData(addresses, shares);
    }

    function testFailSeedWithdrawalDataTooFewShares() public {
        addresses.push(address(1));
        addresses.push(address(2));
        addresses.push(address(3));
        addresses.push(address(4));
        shares.push(1000);
        shares.push(2000);
        shares.push(3000);
        shares.push(3999);

        hedsTape.seedWithdrawalData(addresses, shares);
    }

    function testFailSeedWithdrawalDataNotOwner() public {
        cheats.prank(address(1));

        _seedWithdrawalData();
    }

    function testWithdrawShare() public {
        _seedWithdrawalData();

        _beginSale();
        hedsTape.mintHead{value: 0.3 ether}(3);

        cheats.prank(address(1));
        uint balanceBefore = address(1).balance;
        hedsTape.withdrawShare();
        uint balanceAfter = address(1).balance;
        assertEq(balanceAfter - balanceBefore, 0.03 ether);
    }

    function testFailWithdrawShareUnauthorized() public {
        _seedWithdrawalData();

        _beginSale();
        hedsTape.mintHead{value: 0.3 ether}(3);

        cheats.prank(address(5));
        hedsTape.withdrawShare();
    }

    function testCannotWithdrawExcessiveShare() public {
        _seedWithdrawalData();

        _beginSale();
        hedsTape.mintHead{value: 0.3 ether}(3);

        uint balanceBefore = address(1).balance;
        cheats.prank(address(1));
        hedsTape.withdrawShare();
        cheats.prank(address(1));
        hedsTape.withdrawShare();
        cheats.prank(address(1));
        hedsTape.withdrawShare();
        uint balanceAfter = address(1).balance;
        assertEq(balanceAfter - balanceBefore, 0.03 ether);
    }

    function testWithdrawAllShares() public {
        _seedWithdrawalData();

        _beginSale();
        hedsTape.mintHead{value: 0.3 ether}(3);

        cheats.prank(address(1));
        uint balanceBefore1 = address(1).balance;
        hedsTape.withdrawShare();
        uint balanceAfter1 = address(1).balance;
        assertEq(balanceAfter1 - balanceBefore1, 0.03 ether);

        cheats.prank(address(2));
        uint balanceBefore2 = address(2).balance;
        hedsTape.withdrawShare();
        uint balanceAfter2 = address(2).balance;
        assertEq(balanceAfter2 - balanceBefore2, 0.06 ether);

        cheats.prank(address(3));
        uint balanceBefore3 = address(3).balance;
        hedsTape.withdrawShare();
        uint balanceAfter3 = address(3).balance;
        assertEq(balanceAfter3 - balanceBefore3, 0.09 ether);

        cheats.prank(address(4));
        uint balanceBefore4 = address(4).balance;
        hedsTape.withdrawShare();
        uint balanceAfter4 = address(4).balance;
        assertEq(balanceAfter4 - balanceBefore4, 0.12 ether);
    }

    function testFailNotWhitelistedMint() public {
        _beginWhitelistSale();
        (uint64 price, , ,) = hedsTape.saleConfig();
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

    function testFailExcessiveWhitelistMint() public {
        _beginWhitelistSale();
        whitelistAddresses.push(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);
        mints.push(5);
        hedsTape.seedWhitelist(whitelistAddresses, mints);
        (uint64 price, , ,) = hedsTape.saleConfig();
        uint amount = uint(price) * 6;
        hedsTape.whitelistMintHead{value: amount}(6);
    }

    function testFailWhitelistMintHeadBeforeStartTime() public {
        hedsTape.updateWhitelistStartTime(1650000000);
        cheats.warp(1649999999);
        whitelistAddresses.push(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);
        mints.push(5);
        hedsTape.seedWhitelist(whitelistAddresses, mints);
        (uint64 price, , ,) = hedsTape.saleConfig();
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
