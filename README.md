# Lambda Token Faucet

An advanced ERC-20 token faucet with dynamic distribution, referral system, and comprehensive statistics tracking.

## Features

### Core Functionality
- **Lambda Token (LMDA)**: ERC-20 standard token
- **Advanced Faucet System**: Modular architecture with multiple specialized contracts
- **Dynamic Distribution**: Intelligent token distribution based on supply and time

### Admin System (`FaucetAdmin.sol`)
- Owner and operator role-based access control
- Pause/unpause functionality for emergency situations
- Configurable faucet parameters (amount, cooldown, etc.)
- Blacklist management
- Dynamic adjustment controls

### Dynamic Parameters (`FaucetMath.sol`)
- **Balance-Based Adjustment**: Distribution amount scales with faucet balance
  - 100% → 100% multiplier
  - 75% → 80% multiplier
  - 50% → 50% multiplier
  - 25% → 30% multiplier
  - <10% → 10% multiplier
- **Time-Based Adjustment**: Different rates by UTC time
  - 00:00-08:00 UTC → 120% (off-peak bonus)
  - 08:00-16:00 UTC → 100% (normal)
  - 16:00-24:00 UTC → 80% (peak reduction)
- **Usage-Based Cooldown**: Cooldown increases with traffic
  - 0-10 requests/hour → 1x cooldown
  - 11-50 requests/hour → 2x cooldown
  - 51-100 requests/hour → 4x cooldown
  - 100+ requests/hour → 8x cooldown

### Referral System (`ReferralSystem.sol`)
- Unique referral code generation for each user
- New user bonus: 20% extra tokens
- Referrer reward: 10% of base amount per referral
- Comprehensive referral statistics tracking

### Statistics (`FaucetStats.sol`)
- Global statistics (total requests, distribution, unique users)
- Per-user statistics (request count, total received, averages)
- Activity timeframe tracking
- Largest request tracking

## Architecture

```
contracts/
├── Token.sol                    # ERC-20 Lambda Token
├── LambdaFaucet.sol            # Main faucet coordinator
├── FaucetAdmin.sol             # Admin & access control
├── ReferralSystem.sol          # Referral code management
├── FaucetStats.sol             # Statistics tracking
└── libraries/
    └── FaucetMath.sol          # Pure calculation library
```

## Tech Stack
- Solidity ^0.8.27
- Hardhat
- OpenZeppelin Contracts
  - Ownable2Step
  - Pausable
  - ReentrancyGuard

## Usage

### Installation
```bash
npm install
npx hardhat compile
```

### Deployment Order
1. Deploy `Token.sol`
2. Deploy `FaucetAdmin.sol` (with owner, baseAmount, baseCooldown)
3. Deploy `FaucetStats.sol` (with faucet address placeholder)
4. Deploy `ReferralSystem.sol` (with faucet address placeholder)
5. Deploy `LambdaFaucet.sol` (with all contract addresses)
6. Update FaucetAdmin with LambdaFaucet address
7. Update ReferralSystem and FaucetStats with LambdaFaucet address
8. Fund LambdaFaucet with tokens

### User Interactions

**Request Tokens:**
```solidity
// First-time user with referral code
faucet.requestTokens(referralCode);

// Regular request
faucet.requestTokens(bytes32(0));
```

**Check Status:**
```solidity
// Get estimated amount
uint256 amount = faucet.getEstimatedAmount(user);

// Get time until next request
uint256 timeLeft = faucet.getTimeUntilNextRequest(user);

// Get referral code
bytes32 code = faucet.getMyReferralCode();

// Get complete user status
(bool canRequest, uint256 timeLeft, uint256 estimated, uint256 total, uint256 count)
    = faucet.getUserStatus(user);
```

### Admin Functions

**Parameter Management:**
```solidity
admin.setBaseAmountPerRequest(150 * 10**18);  // Set to 150 tokens
admin.setBaseCooldownTime(2 hours);            // Set to 2 hours
admin.setDynamicConfig(true, 500000 * 10**18, 1 hours);
```

**Access Control:**
```solidity
admin.pause();                           // Emergency pause
admin.unpause();                         // Resume operations
admin.addToBlacklist(address);           // Blacklist user
admin.removeFromBlacklist(address);      // Remove from blacklist
admin.setOperator(operatorAddress);      // Set operator role
```

## Contract Addresses (Update after deployment)

- **Token**: `0x...`
- **LambdaFaucet**: `0x...`
- **FaucetAdmin**: `0x...`
- **ReferralSystem**: `0x...`
- **FaucetStats**: `0x...`

## Parameters

### Default Configuration
- Base amount: 100 LMDA (100 * 10^18)
- Base cooldown: 1 hour
- Max supply: 500,000 LMDA
- Dynamic adjustments: Enabled
- Referral bonus (new user): 20%
- Referral reward (referrer): 10%

## Security Features
- ReentrancyGuard on main request function
- Ownable2Step for safe ownership transfer
- Pausable for emergency situations
- Blacklist functionality
- Input validation on all parameters
- Solidity 0.8+ automatic overflow protection

## Statistics Queries

```solidity
// Global stats
FaucetStats.GlobalStats memory global = stats.getGlobalStats();

// User stats
FaucetStats.UserStats memory user = stats.getUserStats(address);

// Average request amount
uint256 avg = stats.getAverageRequestAmount();
```

## Development

### Compile
```bash
npx hardhat compile
```

### Test
```bash
npx hardhat test
```

### Deploy
```bash
npx hardhat run scripts/deploy.js
```

## License
MIT


