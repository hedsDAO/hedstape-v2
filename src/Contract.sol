// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ERC721A/ERC721A.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract HedsTape is ERC721A, Ownable {
  // pack into a single storage slot
  struct SaleConfig {
    uint64 price;
    uint32 maxSupply;
    uint32 startTime;
  }

  SaleConfig public saleConfig;

  constructor() ERC721A("hedsTAPE 3", "HT3") {}

  function setSaleConfig(uint64 _price, uint32 _maxSupply, uint32 _startTime) external onlyOwner {
    saleConfig = SaleConfig(
      _price,
      _maxSupply,
      _startTime
    );
  }
}
