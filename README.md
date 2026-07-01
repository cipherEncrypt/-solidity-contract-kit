# Solidity Contract Kit

A small, hand-written set of Solidity smart contract templates to fork and learn
from. Nothing fancy or clever  just clean, commented, well-tested starting points
for the contracts people reach for most often. Everything runs on
[Hardhat](https://hardhat.org/) and comes with a passing test suite.

> ⚠️ **These are learning templates, not production code.** They're here to read,
> fork, and build on. If you're going to deploy something that touches real money,
> get it professionally audited first.

## What's in the box

| Contract | Type | What it does |
|---|---|---|
| `Token.sol` | ERC-20 | Mintable, burnable token with a fixed maximum supply. |
| `NFTCollection.sol` | ERC-721 | Paid public minting, per-token metadata, a supply cap, and owner withdrawals. |
| `Staking.sol` | DeFi | Stake one token, earn another over time using reward-per-token accounting. |
| `Vesting.sol` | Tokenomics | Linear vesting with a cliff, for a single beneficiary. |
| `MultiSigWallet.sol` | Security | A minimal M-of-N multisig: submit → confirm → execute. |

Where it makes sense, the contracts build on the audited
[OpenZeppelin](https://www.openzeppelin.com/contracts) libraries rather than
reinventing them.

## Getting started

You'll need [Node.js](https://nodejs.org/) (v18+). Then:

```bash
npm install      # pull down dependencies
npm run compile  # compile the contracts
npm test         # run the test suite (18 tests)
```

No configuration is needed to compile and test locally — Hardhat spins up an
in-memory network for you.

## Trying it on a testnet (Sepolia)

1. Copy the example env file and fill in your own values:

   ```bash
   cp .env.example .env
   ```

   ```
   SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
   PRIVATE_KEY=your_test_wallet_private_key
   ETHERSCAN_API_KEY=your_etherscan_key   # optional, only needed for verification
   ```

   >  Use a **throwaway wallet** funded from a
   > [Sepolia faucet](https://sepoliafaucet.com/). Never put a real private key in
   > here, and never commit your `.env`.

2. Deploy:

   ```bash
   npm run deploy:sepolia
   ```

By default `scripts/deploy.js` deploys the `Token` contract as an example. Open it
up and change a few lines to deploy any of the others.

## Handy commands

```bash
npm run compile        # compile the contracts
npm test               # run the tests
npm run test:gas       # run the tests with a gas usage report
npm run node           # start a local Hardhat node
npm run deploy         # deploy to the local network
npm run deploy:sepolia # deploy to the Sepolia testnet
```

## How the project is laid out

```
contracts/          Solidity sources
  Token.sol
  NFTCollection.sol
  Staking.sol
  Vesting.sol
  MultiSigWallet.sol
test/               Hardhat + Chai tests
  contracts.test.js
scripts/            Deployment scripts
  deploy.js
hardhat.config.js   Compiler + network config
```

## A few notes worth reading

- **`NFTCollection` doesn't refund overpayment.** If a caller sends more than the
  mint price, the extra stays in the contract. Have your front-end send an exact
  amount, or add refund logic if you need it.
- **`Staking` assumes it's been funded with reward tokens.** Transfer enough reward
  tokens into the contract before people start staking, or claims will revert.
- **`MultiSigWallet` fixes its owners and threshold at deploy time.** That keeps it
  simple; if you need to rotate owners, you'll want to extend it.

## Contributing

Pull requests are welcome — new templates, gas optimizations, and extra tests
especially. Fork it, build something, and open a PR.

## License

[MIT](./LICENSE) — free to use, modify, and share.
