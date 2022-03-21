// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./lib/ERC721A.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "solmate/utils/ReentrancyGuard.sol";

error InsufficientFunds();
error ExceedsMaxSupply();
error BeforeSaleStart();
error FailedTransfer();
error ExceedsWhitelistAllowance();
error UnmatchedLength();

/// @title ERC721 contract for https://heds.io/ HedsTape
/// @author https://github.com/kadenzipfel
contract HedsTape is ERC721A, Ownable, ReentrancyGuard {
  struct SaleConfig {
    uint64 price;
    uint32 maxSupply;
    uint32 startTime;
    uint32 whitelistStartTime;
  }

  /// @notice NFT sale data
  /// @dev Sale data packed into single storage slot
  SaleConfig public saleConfig;

  /// @notice Remaining whitelist mints per address
  mapping(address => uint) public whitelist;

  // TODO: pre-fill with uri
  string private baseUri = '';

  constructor() ERC721A("hedsTAPE 3", "HT3") {
    saleConfig.price = 100000000000000000; // 0.1 ETH
    // TODO: Update maxSupply
    saleConfig.maxSupply = 1100; 
    // TODO: Update startTime
    saleConfig.startTime = 0;
    // TODO: Update whitelistStartTime
    saleConfig.whitelistStartTime = 0;
  }

  /// @notice Mint a HedsTape token
  /// @param _amount Number of tokens to mint
  function mintHead(uint _amount) external payable {
    SaleConfig memory config = saleConfig;
    uint _price = uint(config.price);
    uint _maxSupply = uint(config.maxSupply);
    uint _startTime = uint(config.startTime);

    if (_amount * _price != msg.value) revert InsufficientFunds();
    if (_currentIndex + _amount > _maxSupply) revert ExceedsMaxSupply();
    if (_startTime == 0 || block.timestamp < _startTime) revert BeforeSaleStart();

    _safeMint(msg.sender, _amount);
  }

  /// @notice Mint a HedsTape as a whitelisted individual
  /// @dev Must use reentrancy guard to prevent onERC721Received callback reentrancy
  /// @param _amount Number of tokens to mint
  function whitelistMintHead(uint _amount) external payable nonReentrant {
    SaleConfig memory config = saleConfig;
    uint _price = uint(config.price);
    uint _maxSupply = uint(config.maxSupply);
    uint _whitelistStartTime = uint(config.whitelistStartTime);

    if (_amount * _price != msg.value) revert InsufficientFunds();
    if (_currentIndex + _amount > _maxSupply) revert ExceedsMaxSupply();
    if (_whitelistStartTime == 0 || block.timestamp < _whitelistStartTime) revert BeforeSaleStart();
    if (_amount > whitelist[msg.sender]) revert ExceedsWhitelistAllowance();

    whitelist[msg.sender] -= _amount;
    _safeMint(msg.sender, _amount);
  }

  /// @notice Seed whitelist data - must be contract owner
  /// @dev Each call will overwrite all existing whitelist data
  /// @param addresses Array of addresses to provide data for
  /// @param mints Array of number of mints allowed per corresponding address
  function seedWhitelist(address[] calldata addresses, uint256[] calldata mints)
    external
    onlyOwner
  {
    if (addresses.length != mints.length) revert UnmatchedLength();
    for (uint256 i = 0; i < addresses.length; i++) {
      whitelist[addresses[i]] = mints[i];
    }
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

  /// @notice Update sale start time - must be contract owner
  function updateStartTime(uint32 _startTime) external onlyOwner {
    saleConfig.startTime = _startTime;
  }

  /// @notice Update whitelist start time - must be contract owner
  function updateWhitelistStartTime(uint32 _whitelistStartTime) external onlyOwner {
    saleConfig.whitelistStartTime = _whitelistStartTime;
  }

  /// @notice Withdraw contract balance - must be contract owner
  function withdraw() public onlyOwner {
    (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
    if (!success) revert FailedTransfer();
  }
}
