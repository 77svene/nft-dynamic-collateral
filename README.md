# NFT-Backed Dynamic Collateral Vault

A vault where users deposit NFTs as collateral for borrowing stablecoins. LTV updates dynamically based on ZK-verified floor price oracles.

## Quick Start

```bash
# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Deploy to local network
npx hardhat run scripts/deploy.js --network localhost

# Run tests
npx hardhat test
```

## Deployment

Deploy contracts in order:
1. PriceOracle - `new PriceOracle(adminAddress)`
2. CoreVault - `new CoreVault(nftContract, stablecoin)`
3. LiquidationEngine - `new LiquidationEngine(vaultAddress)`

Update contract addresses in Dashboard.html after deployment.

## Interaction

### Deposit NFT
```javascript
await vault.deposit(nftId);
```

### Borrow Stablecoins
```javascript
await vault.borrow(nftId, amount);
```

### Repay Loan
```javascript
await stablecoin.approve(vault.address, amount);
await vault.repay(nftId, amount);
```

### Liquidate Position
```javascript
await liquidationEngine.liquidate(borrower, nftId);
```

## Dashboard

Open Dashboard.html in browser:
1. Connect wallet (MetaMask)
2. View active positions
3. Check health factor
4. Monitor liquidation risk

## Security Assumptions

### Oracle Trust Model
- PriceOracle uses signature-based updates from admin (oracle operator)
- Admin key must be secured offline or via multisig
- Nonce prevents replay attacks on price updates
- Price updates are verified on-chain via ECDSA recovery

### Liquidation Logic
- Health factor = (NFT Value × MAX_LTV) / Borrowed Amount
- Positions liquidatable when healthFactor < 10000
- Liquidators receive 5% bonus on debt paid
- Admin can pause liquidations in emergencies

### Risk Factors
- Oracle manipulation if admin key compromised
- NFT floor price volatility may cause rapid LTV changes
- No reentrancy protection on external calls
- Single admin controls oracle updates

## Testing

```bash
# Full test suite
npx hardhat test test/TestSuite.js

# Gas reporting
npx hardhat test --gas-reporter
```

## Contract Addresses

After deployment, update Dashboard.html:
- CoreVault: 0x...
- PriceOracle: 0x...
- LiquidationEngine: 0x...
- NFT Contract: 0x...
- Stablecoin: 0x...

## License

MIT