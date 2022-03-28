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

    function testFailMintHeadNoStartTime() public {
        hedsTape.updateStartTime(0);
        (uint64 price, , ,) = hedsTape.saleConfig();
        hedsTape.mintHead{value: price}(1);
    }

    function testFailMintHeadInsufficientFunds() public {
        hedsTape.updateStartTime(1650000000);
        cheats.warp(1650000000);
        (uint64 price, , ,) = hedsTape.saleConfig();
        hedsTape.mintHead{value: price - 1}(1);
    }

    function testFailMintHeadsBeyondMaxSupply() public {
        hedsTape.updateStartTime(1650000000);
        cheats.warp(1650000000);
        (uint64 price, uint32 maxSupply, ,) = hedsTape.saleConfig();
        uint valueToSend = uint(price) * uint(maxSupply + 1);
        hedsTape.mintHead{value: valueToSend}(maxSupply + 1);
    }

    function testMintHead() public {
        hedsTape.updateStartTime(1650000000);
        cheats.warp(1650000000);
        (uint64 price, , ,) = hedsTape.saleConfig();
        hedsTape.mintHead{value: price}(1);
    }

    function testMintHeadsUpToMaxSupply() public {
        hedsTape.updateStartTime(1650000000);
        cheats.warp(1650000000);
        (uint64 price, uint32 maxSupply, ,) = hedsTape.saleConfig();
        uint valueToSend = uint(price) * uint(maxSupply);
        hedsTape.mintHead{value: valueToSend}(maxSupply);
    }

    function testTokenURI() public {
        hedsTape.setBaseUri("ipfs://sup");

        hedsTape.updateStartTime(1650000000);
        cheats.warp(1650000000);
        (uint64 price, uint32 maxSupply, ,) = hedsTape.saleConfig();
        uint valueToSend = uint(price) * uint(maxSupply);
        hedsTape.mintHead{value: valueToSend}(maxSupply);

        string memory uri = hedsTape.tokenURI(0);
        assertEq(uri, "ipfs://sup");
    }

    function testSetBaseUriNotOwner() public {
        cheats.expectRevert(bytes("Ownable: caller is not the owner"));
        cheats.prank(address(1));
        hedsTape.setBaseUri("ipfs://sup");
    }

    function testWithdraw() public {
        hedsTape.updateStartTime(1650000000);
        cheats.warp(1650000000);
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

    function testFailNotWhitelistedMint() public {
        hedsTape.updateWhitelistStartTime(1650000000);
        cheats.warp(1650000000);
        (uint64 price, , ,) = hedsTape.saleConfig();
        hedsTape.whitelistMintHead{value: price}(1);
    }

    address[] addresses;
    uint[] mints;

    function testSeedWhitelist() public {
        addresses.push(address(1));
        addresses.push(address(2));
        addresses.push(address(3));
        mints.push(5);
        mints.push(10);
        mints.push(15);
        hedsTape.seedWhitelist(addresses, mints);
        uint availableMints1 = hedsTape.whitelist(address(1));
        assertEq(availableMints1, 5);
        uint availableMints2 = hedsTape.whitelist(address(2));
        assertEq(availableMints2, 10);
        uint availableMints3 = hedsTape.whitelist(address(3));
        assertEq(availableMints3, 15);
    }

    function testFailExcessiveWhitelistMint() public {
        hedsTape.updateWhitelistStartTime(1650000000);
        cheats.warp(1650000000);
        addresses.push(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);
        mints.push(5);
        hedsTape.seedWhitelist(addresses, mints);
        (uint64 price, , ,) = hedsTape.saleConfig();
        uint amount = uint(price) * 6;
        hedsTape.whitelistMintHead{value: amount}(6);
    }

    function testFailWhitelistMintHeadNoStartTime() public {
        hedsTape.updateWhitelistStartTime(0);
        addresses.push(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);
        mints.push(5);
        hedsTape.seedWhitelist(addresses, mints);
        (uint64 price, , ,) = hedsTape.saleConfig();
        hedsTape.whitelistMintHead{value: price}(1);
    }

    function testFailWhitelistMintHeadBeforeStartTime() public {
        hedsTape.updateWhitelistStartTime(1650000000);
        cheats.warp(1649999999);
        addresses.push(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);
        mints.push(5);
        hedsTape.seedWhitelist(addresses, mints);
        (uint64 price, , ,) = hedsTape.saleConfig();
        hedsTape.whitelistMintHead{value: price}(1);
    }

    function testWhitelistMint() public {
        hedsTape.updateWhitelistStartTime(1650000000);
        cheats.warp(1650000000);
        addresses.push(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);
        mints.push(5);
        hedsTape.seedWhitelist(addresses, mints);
        (uint64 price, , ,) = hedsTape.saleConfig();
        uint amount = uint(price) * 5;
        hedsTape.whitelistMintHead{value: amount}(5);
    }

    fallback() external payable {}
    receive() external payable {}
}
