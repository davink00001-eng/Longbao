# LongBao (LNB) — The Dumpling Dragon

LongBao (龙包) is a fixed-supply BEP-20 token on BNB Smart Chain with a simple, transparent presale: buyers pay BNB and receive tokens immediately at a fixed rate. No curves, no admin minting, no hidden functions.

- **Token:** LongBao (LNB), 1,000,000,000 fixed supply, no admin functions
- **Presale:** 400,000,000 LNB (40% of supply) at 10,000,000 LNB per BNB
- **Hard cap:** 40 BNB · **Min buy:** 0.001 BNB · **Max buy:** 0.02 BNB
- **RewardClaim:** Merkle-based reward distribution for the JAGENT epoch community

## Live deployments (BSC mainnet)

| Contract | Address |
|---|---|
| LongBao token (LNB) | `0x9D1981F4a118e7B6AdDBA53CC27303F94934EE08` |
| Presale | `0x668C9287E4B8BE1B3Fc90ba6e16063b8Ee0bA4C1` |
| RewardClaim | `0x325F1cAE2a7ABd1771047c854787f44FA344135d` |

## Live demo

https://longbaolnb.netlify.app

## Contracts

- `LaunchToken.sol` — the LNB token
- `Presale.sol` — fixed-rate presale (40 BNB hard cap, per-wallet min/max)
- `RewardClaim.sol` — Merkle-proof reward claims

## Links

- Site: https://longbaolnb.netlify.app
- X: https://x.com/longbaolnb
