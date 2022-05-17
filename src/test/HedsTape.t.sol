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

    address[] largeWhitelist;
    uint256[] largeWhitelistMints;

    function setUp() public {
        hedsTape = new HedsTape();

        for (uint i = 0; i < 1000; i++) {
            largeWhitelist.push(address(1));
            largeWhitelistMints.push(1);
        }
    }

    address[] addresses;
    uint64[] shares;
    address[] whitelistAddresses;
    uint[] mints;

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
        whitelistAddresses.push(address(this));
        mints.push(5);
        hedsTape.seedWhitelist(whitelistAddresses, mints);
        (uint64 price, , ,) = hedsTape.saleConfig();
        uint amount = uint(price) * 6;
        cheats.expectRevert(abi.encodeWithSignature("ExceedsWhitelistAllowance()"));
        hedsTape.whitelistMintHead{value: amount}(6);
    }

    function testCannotExcessiveWhitelistMintSeparateTx() public {
        _beginWhitelistSale();
        whitelistAddresses.push(address(this));
        mints.push(5);
        hedsTape.seedWhitelist(whitelistAddresses, mints);
        (uint64 price, , ,) = hedsTape.saleConfig();
        uint amount = uint(price) * 5;
        hedsTape.whitelistMintHead{value: amount}(5);

        cheats.expectRevert(abi.encodeWithSignature("ExceedsWhitelistAllowance()"));
        hedsTape.whitelistMintHead{value: price}(1);
    }

    function testCannotWhitelistMintHeadBeforeStartTime() public {
        hedsTape.updateWhitelistStartTime(1650000000);
        cheats.warp(1649999999);
        whitelistAddresses.push(address(this));
        mints.push(5);
        hedsTape.seedWhitelist(whitelistAddresses, mints);
        (uint64 price, , ,) = hedsTape.saleConfig();
        cheats.expectRevert(abi.encodeWithSignature("BeforeSaleStart()"));
        hedsTape.whitelistMintHead{value: price}(1);
    }

    function testWhitelistMint() public {
        _beginWhitelistSale();
        whitelistAddresses.push(address(this));
        mints.push(5);
        hedsTape.seedWhitelist(whitelistAddresses, mints);
        (uint64 price, , ,) = hedsTape.saleConfig();
        uint amount = uint(price) * 5;
        hedsTape.whitelistMintHead{value: amount}(5);
    }

    function testSeedLargeWhitelist() public {
        hedsTape.seedWhitelist(largeWhitelist, largeWhitelistMints);
    }

    fallback() external payable {}
    receive() external payable {}
}
