// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "./lib/ERC721A.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

error InsufficientFunds();
error ExceedsMaxSupply();
error BeforeSaleStart();
error FailedTransfer();

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

  function mintHead(uint _amount) public payable {
    SaleConfig memory config = saleConfig;
    uint _price = uint(config.price);
    uint _maxSupply = uint(config.maxSupply);
    uint _startTime = uint(config.startTime);

    if (_amount * _price != msg.value) revert InsufficientFunds();
    if (_currentIndex + _amount > _maxSupply - 1) revert ExceedsMaxSupply();
    if (_startTime == 0 || block.timestamp < _startTime) revert BeforeSaleStart();

    _safeMint(msg.sender, _amount);
  }

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

  function withdraw() public onlyOwner {
    (bool success, ) = msg.sender.call{value: address(this).balance}("");
    if (!success) revert FailedTransfer();
  }
}
