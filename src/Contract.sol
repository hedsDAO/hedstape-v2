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

  // TODO: pre-fill with uri
  string private baseUri = '';

  constructor() ERC721A("hedsTAPE 3", "HT3") {}

  function setBaseUri(string calldata _baseUri) external onlyOwner {
    baseUri = _baseUri;
  }

  function tokenURI(uint tokenId) public view override returns (string memory) {
    if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
    return baseUri;
  }

  function setSaleConfig(uint64 _price, uint32 _maxSupply, uint32 _startTime) external onlyOwner {
    saleConfig = SaleConfig(
      _price,
      _maxSupply,
      _startTime
    );
  }
}
