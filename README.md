# Decentralized Lending Platform

A comprehensive DeFi lending platform built on Stacks blockchain using Clarity smart contracts. This platform enables users to lend, borrow, and manage collateral in a decentralized manner with built-in credit scoring and insurance mechanisms.

## 🏗️ Architecture Overview

The platform consists of four main smart contracts:

### 1. Lending Pool Contract (`lending-pool.clar`)
- Manages multiple lending pools for different assets
- Handles interest rate calculations based on utilization
- Processes lending and borrowing operations
- Tracks pool statistics and user positions

### 2. Collateral Contract (`collateral.clar`)
- Manages collateral deposits and withdrawals
- Calculates collateralization ratios
- Handles liquidation processes
- Supports multiple collateral types with different LTV ratios

### 3. User Rating Contract (`user-rating.clar`)
- Maintains credit scores for borrowers
- Updates ratings based on repayment history
- Provides risk assessment for lending decisions
- Implements reputation-based interest rate adjustments

### 4. Insurance Contract (`insurance.clar`)
- Provides coverage for lenders against borrower defaults
- Manages insurance pool contributions
- Handles claim processing and payouts
- Calculates insurance premiums based on risk factors

## 🚀 Features

- **Multi-Asset Support**: Support for STX and various SIP-010 tokens
- **Dynamic Interest Rates**: Rates adjust based on supply/demand and borrower credit scores
- **Automated Liquidations**: Smart contract-based liquidation when collateral falls below threshold
- **Credit Scoring**: On-chain reputation system for borrowers
- **Insurance Protection**: Optional insurance coverage for lenders
- **Governance Ready**: Designed for future DAO governance integration

## 📋 Contract Functions

### Lending Pool Contract
- `create-pool`: Create a new lending pool for an asset
- `supply-to-pool`: Supply assets to earn interest
- `borrow-from-pool`: Borrow assets against collateral
- `repay-loan`: Repay borrowed amount with interest
- `withdraw-supply`: Withdraw supplied assets
- `get-pool-info`: Get pool statistics and parameters

### Collateral Contract
- `deposit-collateral`: Deposit collateral to secure loans
- `withdraw-collateral`: Withdraw excess collateral
- `liquidate-position`: Liquidate undercollateralized positions
- `get-collateral-ratio`: Calculate current collateralization ratio
- `update-collateral-price`: Update asset prices (oracle integration)

### User Rating Contract
- `initialize-user`: Create initial credit profile
- `update-rating`: Update user's credit score
- `get-user-rating`: Retrieve user's current rating
- `calculate-risk-premium`: Calculate interest rate adjustment

### Insurance Contract
- `contribute-to-pool`: Add funds to insurance pool
- `purchase-coverage`: Buy insurance for lending position
- `file-claim`: File insurance claim for default
- `process-claim`: Process and pay valid claims

## 🔧 Installation & Setup

\`\`\`bash
# Clone the repository
git clone <repository-url>
cd defi-lending-platform

# Install dependencies
npm install

# Run tests
npm test

# Deploy contracts (requires Stacks CLI)
clarinet deploy
\`\`\`

## 🧪 Testing

The project uses Vitest for comprehensive testing:

\`\`\`bash
# Run all tests
npm test

# Run specific test file
npm test lending-pool.test.js

# Run tests in watch mode
npm test -- --watch
\`\`\`

## 📊 Risk Management

### Collateralization Requirements
- **STX**: 150% minimum collateralization ratio
- **SIP-010 Tokens**: 200% minimum collateralization ratio
- **Liquidation Threshold**: 120% for STX, 150% for tokens

### Interest Rate Model
- Base rate: 2% APY
- Utilization multiplier: Dynamic based on pool usage
- Credit score adjustment: ±2% based on borrower rating
- Insurance premium: 0.5-2% based on coverage level

### Security Features
- Multi-signature admin functions
- Time-locked parameter changes
- Emergency pause functionality
- Comprehensive input validation

## 🔐 Security Considerations

- All contracts implement proper access controls
- Critical functions require multi-signature approval
- Price oracle integration with multiple data sources
- Comprehensive testing coverage including edge cases
- Regular security audits recommended

## 📈 Roadmap

- [ ] Oracle integration for real-time price feeds
- [ ] Governance token and DAO implementation
- [ ] Cross-chain bridge integration
- [ ] Advanced derivatives and yield farming
- [ ] Mobile application interface
- [ ] Institutional lending features

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Implement changes with tests
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Project Website](#)
- [Discord Community](#)
