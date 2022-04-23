# HedsTape 04

### Todo before deployment:

- [ ] Set baseUri
  - [ ] Remove corresponding todo comment
- [ ] Set all saleConfig values (in constructor)
  - [ ] Remove corresponding todo comment
- [ ] Create release once previous steps complete

### Todo after deployment:

- [ ] seedWhitelist
  - Input array of addresses (e.g. [0xabc..., 0x123..., 0xa1b...]) and corresponding mint amounts per address (e.g. [3, 8, 5])
- [ ] seedWithdrawalData
  - Input array of addresses (e.g. [0xabc..., 0x123..., 0xa1b...]) and corresponding bps of total funds to allot to address
  - 10000 bps = 100%, so if you want to allot 10% of funds to an address, input 1000
- [ ] Verify contract

### Notes:

- Whitelist minting uses a separate function from regular minting, for whitelist mints use whitelistMintHead()
- emergencyWithdraw() will break withdrawShare() functionality, only use in emergency
