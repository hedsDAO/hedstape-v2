// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ERC721A/ERC721A.sol";

contract HedsTape is ERC721A {
  // pack into a single storage slot
  struct SaleConfig {
    uint64 price;
    uint32 maxSupply;
    uint32 startTime;
  }

  SaleConfig public saleConfig;

  constructor() ERC721A("hedsTAPE 3", "HT3") {}
}
