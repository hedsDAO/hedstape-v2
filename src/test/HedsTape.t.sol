// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../HedsTape.sol";

contract ContractTest is DSTest {
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
}
