# 🎵 Music Royalty Split Engine

> **Automated, verifiable distribution of streaming royalties between contributors across Pan-Africa** 🌍

## 🚀 Overview

The Music Royalty Split Engine is a smart contract built on Stacks that ensures **fair and transparent royalty distribution** for music creators. Using Clarity's precise mathematical operations, it eliminates disputes and provides verifiable payment splits between all song contributors.

## ✨ Key Features

- 🎯 **Precise Split Calculations** - No more payment disputes
- 🔒 **Transparent Distribution** - All transactions are verifiable on-chain
- 👥 **Multi-Contributor Support** - Up to 20 contributors per song
- 📊 **Payment History Tracking** - Complete audit trail
- ⚡ **Automated Royalty Claims** - Contributors claim their shares directly
- 🛡️ **Access Control** - Only authorized distributors can register songs

## 🔧 Core Functions

### Register New Song
```clarity
(register-song "Song Title" "Artist Name" 
  (list 
    { contributor: 'SP1..., split: u5000 }  ; 50%
    { contributor: 'SP2..., split: u3000 }  ; 30% 
    { contributor: 'SP3..., split: u2000 }  ; 20%
  )
)
```

### Distribute Royalties
```clarity
(distribute-royalties song-id total-amount)
```

### Claim Your Share
```clarity
(claim-royalty song-id distribution-id)
```

## 📋 Usage Instructions

### 1. **Song Registration** 🎼
- Only the contract owner can register new songs
- Split percentages must total exactly 10,000 (100%)
- Each contributor gets a defined percentage of future royalties

### 2. **Royalty Distribution** 💰
- Contract owner distributes royalties for registered songs
- System automatically calculates each contributor's share
- Distribution history is permanently recorded

### 3. **Claiming Royalties** 🏦
- Contributors claim their share from specific distributions
- Payments are transferred directly to contributor wallets
- Running total of received payments is maintained

## 🔍 Read-Only Functions

- `get-song-details` - View song information
- `get-contributor-info` - Check contributor splits and earnings
- `get-distribution-history` - Review past distributions
- `calculate-share` - Preview payment amounts
- `get-total-songs` - Count registered songs

## 💡 Split Percentage System

The contract uses **basis points** for precise calculations:
- `u10000` = 100%
- `u5000` = 50%
- `u2500` = 25%
- `u1000` = 10%

## 🛠️ Development Setup

1. **Install Clarinet**
   ```bash
   npm install -g @hirosystems/clarinet-cli
   ```

2. **Clone and Deploy**
   ```bash
   clarinet console
   ::deploy_contracts
   ```

3. **Run Tests**
   ```bash
   clarinet test
   ```

## 🎯 Example Use Case

**Scenario:** A song has 3 contributors
- Producer: 50% (u5000)
- Artist: 30% (u3000)  
- Songwriter: 20% (u2000)

When **$1000** in royalties is distributed:
- Producer receives: **$500**
- Artist receives: **$300**
- Songwriter receives: **$200**

## 🔐 Security Features

- ✅ Owner-only song registration
- ✅ Validated split percentages  
- ✅ Insufficient funds protection
- ✅ Contributor verification
- ✅ Immutable payment history

## 🌟 Impact

**Fair Payments** - Every contributor gets exactly their agreed percentage  
**No Disputes** - Clarity's math is precise and verifiable  
**Transparency** - All distributions are publicly auditable  
**Pan-African Focus** - Designed for the growing African music market 🎶

---

*Built with ❤️ using Clarity smart contracts on Stacks blockchain*
