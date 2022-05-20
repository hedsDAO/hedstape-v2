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

    address zeroXSplit = 0x3058435589213f59e8653D1410508bCd3F7a4DfD;

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns(bytes4) {
        return this.onERC721Received.selector;
    }

    function setUp() public {
        hedsTape = new HedsTape();
    }

    function _beginSale() internal {
        hedsTape.updateStartTime(1650000000);
        cheats.warp(1650000000);
    }

    function testUpdateStartTimeAsOwner() public {
        hedsTape.updateStartTime(1650000000);
        (, , uint32 newStartTime) = hedsTape.saleConfig();

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
        (uint64 price, ,) = hedsTape.saleConfig();
        cheats.expectRevert(abi.encodeWithSignature("BeforeSaleStart()"));
        hedsTape.mintHead{value: price}(1);
    }

    function testCannotMintHeadInsufficientFunds() public {
        _beginSale();
        (uint64 price, ,) = hedsTape.saleConfig();
        cheats.expectRevert(abi.encodeWithSignature("InsufficientFunds()"));
        hedsTape.mintHead{value: price - 1}(1);
    }

    function testCannotMintHeadsBeyondMaxSupply() public {
        _beginSale();
        (uint64 price, uint32 maxSupply,) = hedsTape.saleConfig();
        uint valueToSend = uint(price) * uint(maxSupply + 1);
        cheats.expectRevert(abi.encodeWithSignature("ExceedsMaxSupply()"));
        hedsTape.mintHead{value: valueToSend}(maxSupply + 1);
    }

    function testMintHead() public {
        _beginSale();
        (uint64 price, ,) = hedsTape.saleConfig();
        hedsTape.mintHead{value: price}(1);
    }

    function testMintHeads(uint16 amount) public {
        (uint64 price, uint32 maxSupply,) = hedsTape.saleConfig();
        if (amount > maxSupply) amount = uint16(maxSupply);
        if (amount == 0) amount = 1;

        _beginSale();

        uint valueToSend = uint(price) * uint(amount);

        hedsTape.mintHead{value: valueToSend}(amount);
    }

    function testMintHeadsUpToMaxSupply() public {
        _beginSale();
        (uint64 price, uint32 maxSupply,) = hedsTape.saleConfig();
        uint valueToSend = uint(price) * uint(maxSupply);
        hedsTape.mintHead{value: valueToSend}(maxSupply);
    }

    function testTokenURI() public {
        hedsTape.setBaseUri("ipfs://sup");

        _beginSale();
        (uint64 price, uint32 maxSupply,) = hedsTape.saleConfig();
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
        (uint64 price, uint32 maxSupply,) = hedsTape.saleConfig();
        uint amount = uint(price) * uint(maxSupply);
        hedsTape.mintHead{value: amount}(maxSupply);

        assertEq(address(hedsTape).balance, amount);

        uint balanceBefore = address(zeroXSplit).balance;
        hedsTape.withdraw();
        uint balanceAfter = address(zeroXSplit).balance;

        assertEq(balanceAfter - balanceBefore, amount);
    }

    function testWithdrawNotOwner() public {
        cheats.expectRevert(bytes("Ownable: caller is not the owner"));
        cheats.prank(address(1));
        hedsTape.withdraw();
    }

    fallback() external payable {}
    receive() external payable {}
}
