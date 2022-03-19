// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../HedsTape.sol";

interface CheatCodes {
  function prank(address) external;
  function expectRevert(bytes calldata) external;
  function expectRevert(bytes4) external;
  function warp(uint256) external;
}

contract HedsTapeTest is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    HedsTape hedsTape;

    function setUp() public {
        hedsTape = new HedsTape();
    }

    function testUpdateStartTimeAsOwner() public {
        (, , uint32 startTime) = hedsTape.saleConfig();

        assertEq(startTime, 0);

        hedsTape.updateStartTime(1647721808);
        (, , uint32 newStartTime) = hedsTape.saleConfig();

        assertEq(newStartTime, 1647721808);
    }

    function testUpdateStartTimeAsNotOwner() public {
        cheats.expectRevert(bytes("Ownable: caller is not the owner"));
        cheats.prank(address(0));
        hedsTape.updateStartTime(1647721808);
    }

    function testFailMintHeadBeforeStartTime() public {
        hedsTape.updateStartTime(1650000000);
        cheats.warp(1649999999);
        hedsTape.mintHead{value: 100000000000000000}(1);
    }

    function testFailMintHeadNoStartTime() public {
        hedsTape.mintHead{value: 100000000000000000}(1);
    }

    function testFailMintHeadInsufficientFunds() public {
        hedsTape.updateStartTime(1650000000);
        cheats.warp(1650000000);
        hedsTape.mintHead{value: 10000000000000000}(1);
    }
}
