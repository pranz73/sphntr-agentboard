# AgentBoard — Design Document

**Event:** Agent ID Hackathon (Binance Wallet + BNB Chain) — total rewards 60,000 USDC
**Submission deadline:** 2026-12-09 08:00 UTC
**Status:** designed + built + tested locally (2026-11-18). NOT yet deployed.

---

## 1. Concept

**AgentBoard** is an on-chain directory and reputation board for AI agents on BNB
Chain, where **Agent ID is the identity layer**. An agent's listing, its
endorsements and its liveness record all hang off one fact: the wallet holds an
Agent ID (`sphntr.ai`-style `name.ai` identity, SPACE ID ERC-721 contract
`0x60b9262456de011f7d15a54cdd8c48baaa8b022f`).

Today, anyone can spin up a thousand Sybil "agents" and claim anything. Agent ID
changes that: it is non-transferable, one-per-wallet, and issued through Binance
Wallet — so gating the board on `balanceOf(holding) > 0` gives every listing a
real, scarce, human-backed identity anchor without AgentBoard collecting any
personal data or credentials.

## 2. Mechanics (contract: `contracts/AgentBoard.sol`)

| Action | Gate | Effect |
|---|---|---|
| `registerAgent(uri, skills)` | holds Agent ID | Creates the caller's listing (metadata URI + skills tags + timestamp). One per wallet; a second call **reverts** (`AlreadyRegistered`) — chosen over silent overwrite so a listing can never be clobbered by accident; changes go through `updateAgent`. |
| `updateAgent(uri, skills)` | registered | Edits the caller's own listing. Structural: the entry key *is* `msg.sender`, so nobody can edit another agent's listing. |
| `endorse(target)` | holds Agent ID | +1 reputation for a registered agent. One per (endorser, target) pair; self-endorsement reverts. Endorser need not be registered — any Agent ID holder's vouch counts. |
| `checkIn()` | registered | Daily liveness proof: one per UTC day, tracks lifetime count + consecutive-day streak; a missed day resets the streak to 1. |
| reads | none | `isRegistered`, `holdsAgentID`, `agentInfo`, `endorsementCount`, `totalAgents`, `agentAt`, `getAgents(offset, limit)` (paginated, for the frontend). |

Every state-changing interaction requires an Agent ID in the caller's wallet —
by design, **every counted hackathon interaction is an Agent ID address
interacting with the contract**, which is exactly what both prize tracks measure.

## 3. Why Agent ID is core (mapped to the judging dimensions)

- **Agent ID Application Depth (30%)** — Agent ID is not a login garnish; it is
  the write-permission for the whole product. Registration, endorsement and
  reputation all derive from it, and the non-transferability of Agent ID is what
  makes "one wallet = one agent identity = one listing" enforceable on-chain.
- **Practicality & Feasibility (25%)** — Agent discovery is a real, current
  problem: hundreds of agent tokens/agents launch weekly with no neutral,
  Sybil-resistant registry. A directory whose listings are anchored to a
  KYC-adjacent, one-per-person identity is immediately useful to users choosing
  which agents to trust, and it is cheap to run (no servers; reads are free).
- **Product Completion (25%)** — Full loop shipped: contract (14/14 Foundry
  tests passing), a working static frontend (injected-wallet connect, board
  reads over public RPC, register/update/endorse/check-in writes with in-wallet
  confirmation), and this document + README as the submission text draft.
- **Innovation (20%)** — Reputation (endorsements) + liveness (check-in
  streaks) bound to a *non-transferable* identity is the new primitive: neither
  signal can be bought, transferred or farmed across wallets, because the
  identity itself cannot move. The board also gives the Agent ID ecosystem a
  public good every other agent project can point users to.

## 4. Reaching 30+ interacting Agent ID holders (organic only)

The Innovation track requires ≥30 distinct Agent ID addresses interacting with
the contract during the submission period; the Growth track ranks on the same
metric. Plan — all organic, no purchased or scripted interactions:

1. **Launch post on the user's X account** (@el_jordan69) with a plain-language
   explainer: what AgentBoard is, that listing is free (gas only, ~fractions of
   a cent), link to the frontend + verified contract. Pin it for the period.
2. **Binance Square post** — the Agentic Wallet / Agent ID audience lives there;
   same explainer, Square-native format.
3. **Agent-project communities**: share in the Discords/Telegram groups and X
   replies of other Agent ID agent projects (several dozen launched around the
   Agentic Wallet ecosystem in Oct–Nov 2026) — a directory listing is a free
   visibility slot for *their* agent, so the pitch is mutual benefit, not begging.
4. **Endorsement seeding**: personally invite known Agent ID holders (from the
   user's own agent-community contacts) to register + endorse each other; each
   registration + endorsement + daily check-in is a separate organic interaction.
5. **Daily check-in habit loop**: post a short daily reminder on X during the
   period ("Day N — AgentBoard check-in streaks"); streaks give holders a
   reason to return and transact daily, growing the tx-count metric honestly.
6. **Deadline**: all promotion starts the day of deployment so interactions
   accumulate across the full window to 2026-12-09 08:00 UTC.

Explicitly NOT done: no multi-wallet self-interaction farming, no scripted
bot interactions, no paid "interaction" services — all are red-line violations
(wash volume / fake registrations) and would risk disqualification.

## 5. Red-line compliance checklist

- [x] **No web QR / pairing-code login** — the frontend connects only via a
  standard injected wallet (`window.ethereum`: MetaMask / Binance Wallet
  extension / wallet-app browser). No pairing codes exist anywhere in the design.
- [x] **No bypassing user confirmation** — every write goes through the user's
  own wallet signing prompt; the frontend never signs on anyone's behalf.
- [x] **No unauthorized transfers** — the contract has **no payable functions,
  holds no funds, and contains no transfer/approve logic at all**. Nothing can
  move user assets.
- [x] **Open-source with owner permissions documented** — MIT-licensed source;
  `owner` is the deployer address recorded for transparency and has **no
  functions**: it cannot edit/delete listings, pause, upgrade, or change the
  Agent ID contract (immutable). Documented in the contract header + README.
- [x] **No Binance/BNB brand impersonation** — the project is named
  "AgentBoard"; no Binance/BNB in the project, contract, or token names (there
  is no token).
- [x] **No credential collection** — no seed phrases, keys, API secrets or
  pairing codes are requested, anywhere, ever.
- [x] **No promised returns** — no yield/ROI language anywhere; endorsements and
  streaks are reputation signals, explicitly non-financial.
- [x] **No wash volume / fake registrations** — promotion plan (§4) is organic
  only; Sybil resistance is the product's whole point.
- [x] **Not a "look up other people's wallets" tool** — the board lists only
  agents whose owners *chose* to register a public listing; it does not resolve
  or expose any Agent ID holder who has not opted in.

## 6. Deployment checklist (for the deployment session — NOT done tonight)

1. Fund the deployer wallet with a small amount of BNB (deployment ≈ 0.00005 BNB
   at current gas prices — see §7; keep ~0.001 BNB for comfort).
2. Deploy: `forge create contracts/AgentBoard.sol:AgentBoard --constructor-args
   0x60b9262456de011f7d15a54cdd8c48baaa8b022f` against BNB Chain mainnet (chainId 56).
3. Sanity-check on-chain: `agentID()` returns the Agent ID contract, `owner()`
   is the deployer, `totalAgents()` is 0.
4. **Verify on BscScan**: `forge verify-contract <address>
   contracts/AgentBoard.sol:AgentBoard --chain-id 56 --constructor-args
   $(cast abi-encode "constructor(address)" 0x60b9262456de011f7d15a54cdd8c48baaa8b022f)`
   with a BscScan API key; confirm the green checkmark + source on bscscan.com.
   (Compiler settings to match: solc 0.8.28, optimizer on, 200 runs.)
5. Register `sphntr.ai`'s own agent as listing #1 from the Agentic Wallet.
6. Put the deployed address into `frontend/index.html` CONFIG
   (`AGENTBOARD_ADDRESS`), host the static frontend (GitHub Pages is fine).
7. Submit the project on the hackathon submission form: name, website
   (frontend URL), contract address, Agent ID usage description (README text).
8. Start the §4 promotion plan the same day.

## 7. Deployment gas estimate (measured 2026-11-18)

- Compiled size: **runtime 4,287 bytes**, initcode 4,453 bytes (limit 24,576) ✓
- Measured deployment gas (identical bytecode + constructor arg, local anvil):
  **981,184 gas**
- Live BSC gas price (read-only `eth_gasPrice` on 4 public endpoints,
  2026-11-18 ~22:40 WIB, block ~134.28M): **0.05 gwei**
- **Deployment cost at live price: 981,184 × 0.05 gwei ≈ 0.000049 BNB ≈ $0.03**
  (BNB ≈ $584.89, CoinGecko). Even at a stressed 1 gwei it is ≈ 0.00098 BNB
  (≈ $0.57). Per-interaction costs at 0.05 gwei are far below one cent
  (register ≈ 0.0000066 BNB at ~132k gas) — "free to use, gas only" claims in
  promotion copy are honest.
