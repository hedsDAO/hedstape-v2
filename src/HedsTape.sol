// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./lib/ERC721A.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

error InsufficientFunds();
error ExceedsMaxSupply();
error BeforeSaleStart();
error FailedTransfer();

/// @title ERC721 contract for https://heds.io/ HedsTape
/// @author https://github.com/kadenzipfel
contract HedsTape is ERC721A, Ownable {
  struct SaleConfig {
    uint64 price;
    uint32 maxSupply;
    uint32 startTime;
  }

  /// @notice NFT sale data
  /// @dev Sale data packed into single storage slot
  SaleConfig public saleConfig;

  // TODO: pre-fill with uri
  string private baseUri = '';

  constructor() ERC721A("hedsTAPE 3", "HT3") {}

  /// @notice Mint a HedsTape token
  /// @param _amount Number of tokens to mint
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

  /// @notice Update baseUri - must be contract owner
  function setBaseUri(string calldata _baseUri) external onlyOwner {
    baseUri = _baseUri;
  }

  /// @notice Return tokenURI for a given token
  /// @dev Same tokenURI returned for all tokenId's
  function tokenURI(uint _tokenId) public view override returns (string memory) {
    if (!_exists(_tokenId)) revert URIQueryForNonexistentToken();
    return baseUri;
  }

  /// @notice Update token sale data - must be contract owner
  function setSaleConfig(uint64 _price, uint32 _maxSupply, uint32 _startTime) external onlyOwner {
    saleConfig = SaleConfig(
      _price,
      _maxSupply,
      _startTime
    );
  }

  /// @notice Withdraw contract balance - must be contract owner
  function withdraw() public onlyOwner {
    (bool success, ) = msg.sender.call{value: address(this).balance}("");
    if (!success) revert FailedTransfer();
  }
}
