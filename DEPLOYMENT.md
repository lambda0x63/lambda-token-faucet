# LambdaFaucet Sepolia Testnet Deployment

## Deployment Details
- **Network**: Sepolia Testnet
- **Date**: October 27, 2025
- **Deployer**: 0x31CC996b5959Cba733C03c77Ce0Ed0711a1b05A0

## Deployed Contract Addresses

### 1. LambdaToken (ERC-20 Token)
- **Address**: `0x0E0f45Fa06E8db3A0a164D4790CbF9dDA1854f77`
- **Etherscan**: https://sepolia.etherscan.io/address/0x0E0f45Fa06E8db3A0a164D4790CbF9dDA1854f77
- **Symbol**: LMDA
- **Total Supply**: 1,000,000 LMDA
- **Decimals**: 18

### 2. FaucetAdmin (Administrative Functions)
- **Address**: `0x7aBED62BFD3369563e93e2388275996Ae751FBAa`
- **Etherscan**: https://sepolia.etherscan.io/address/0x7aBED62BFD3369563e93e2388275996Ae751FBAa
- **Base Amount**: 100 LMDA per request
- **Base Cooldown**: 3600 seconds (1 hour)
- **Features**: Role-based access control, pausable, blacklist management

### 3. FaucetStats (Statistics Tracking)
- **Address**: `0xEafb1453828e6039D58CCf35ed2a7cb2f49bCbbE`
- **Etherscan**: https://sepolia.etherscan.io/address/0xEafb1453828e6039D58CCf35ed2a7cb2f49bCbbE
- **Purpose**: Records global and per-user statistics
- **Tracks**: Total requests, distribution amount, unique users, user activity

### 4. ReferralSystem (Referral Rewards)
- **Address**: `0x6389E901F489a9E87822f40DF97B43a386E45b05`
- **Etherscan**: https://sepolia.etherscan.io/address/0x6389E901F489a9E87822f40DF97B43a386E45b05
- **New User Bonus**: 20% extra tokens
- **Referrer Reward**: 10% of base amount per successful referral
- **Features**: Unique referral codes, referral tracking

### 5. LambdaFaucet (Main Integration Hub) ⭐
- **Address**: `0x6c005cb11774bC71081fa6A3e33F155ffFCC0616`
- **Etherscan**: https://sepolia.etherscan.io/address/0x6c005cb11774bC71081fa6A3e33F155ffFCC0616
- **Purpose**: Main faucet contract that coordinates all modules
- **Features**:
  - Dynamic token distribution based on faucet balance
  - Time-based multipliers (off-peak bonus, peak reduction)
  - Usage-based cooldown adjustments
  - ReentrancyGuard protection

## Interacting with Contracts on Etherscan

### Checking Token Information
1. Visit LambdaToken address above
2. Click "Read Contract" tab
3. Use `balanceOf()` to check token balance
4. Use `totalSupply()` to check total supply

### Requesting Tokens from Faucet
1. Visit LambdaFaucet address above
2. Click "Write Contract" tab
3. Connect your wallet with MetaMask
4. Call `requestTokens()` function
5. Sign the transaction

### Checking User Statistics
1. Visit FaucetStats address above
2. Click "Read Contract" tab
3. Use `userStats()` to view per-user statistics
4. Use `globalStats()` to view global statistics

## Deployment Script

To deploy LambdaFaucet to Sepolia testnet:

```bash
# Set up environment variables in .env file
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
PRIVATE_KEY=YOUR_PRIVATE_KEY

# Run deployment
npx hardhat run scripts/deployLambdaFaucet.ts --network sepolia
```

## Initial State

- ✅ Created 1,000,000 LMDA tokens
- ✅ Funded LambdaFaucet with 50,000 LMDA
- ✅ All modules properly initialized and connected
- ✅ Users can request tokens from the faucet
- ✅ Statistics tracking is active
- ✅ Referral system is operational

## Contract Architecture

```
LambdaFaucet (Main Hub)
├── LambdaToken (ERC-20)
├── FaucetAdmin (Admin & Params)
├── FaucetStats (Statistics)
└── ReferralSystem (Referrals)
```

## Important Notes

- ⚠️ Deployed on Sepolia testnet (not mainnet)
- ⚠️ Tokens have no real value
- ⚠️ For testing purposes only
- ✅ All contracts are deployed and functional
- ✅ Contracts can be verified on Etherscan

## Contract Verification

All contracts can be verified on Etherscan using the deployment transaction hashes. Source code is available on GitHub.
