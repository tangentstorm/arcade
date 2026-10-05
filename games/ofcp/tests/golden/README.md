# OFCP Golden Test Vectors

Golden inputs/outputs for porting the Pineapple OFCP engine (`tangentstorm/ofcp` @ `9d4f481`) to Godot GDScript. Another agent should implement `types`, `deck`, `hand-eval`, `scoring`, `game`, `play-profile` and check against these files.

**Do not invent royalty tables or foul rules from memory — use `RULES-SPEC.md` and these vectors.**

## Regenerate

From the TypeScript repo (does not modify engine source; does not git commit):

```bash
cd /workspace/ofcp
npx tsx scripts/gen-golden.ts
```

Writes/overwrites JSON in `/workspace/ofcp-golden/`. Uses **real** `src/` functions plus a fixed-seed mulberry32 PRNG for random cases.

## Card encoding

Every card is a two-character string: **rank** + **suit**.

| | Values |
|--|--------|
| Rank | `2` `3` `4` `5` `6` `7` `8` `9` `T` `J` `Q` `K` `A` |
| Suit | `h` hearts, `d` diamonds, `c` clubs, `s` spades |

Examples: `As` = Ace of spades, `Td` = Ten of diamonds, `2c` = Two of clubs.

Boards are objects `{ "top": [...], "middle": [...], "bottom": [...] }` with 3 / 5 / 5 cards when complete.

## Files

| File | Contents | Approx. size |
|------|----------|--------------|
| `eval5.json` | 5-card `evaluate5` hands + pairwise `compare` (−1/0/1) | ~140 hands, ~70 compares |
| `eval3.json` | 3-card top `evaluate3`, compares, and **crossRow** top-vs-middle foul compares | ~90 hands, ~45 compares, ~47 crossRow |
| `boards.json` | Full 13-card boards → fouled, royalties, FL qualify / stay / card counts per profile | ~90 boards |
| `score_hu.json` | Two boards → row results, scoop, royalties, net scores (incl. one-foul & both-foul) | ~50 cases |
| `score_multi.json` | 3-way via `scoreVsOpponents` → net per player (foul pays both) | ~35 cases |
| `game_flow.json` | Seeded shuffle + deal sequence (2p & 3p), pineapple 3-pick-2 ×4, FL deal sizes | deal traces |
| `RULES-SPEC.md` | Rules as implemented in code | — |
| `README.md` | This file | — |

Exact counts are printed by the generator and live in each file’s `meta` / structure.

## Field meanings (summary)

### Shared

- `category` / `categoryName` — `HandCategory` 0–9 (`HIGH_CARD` … `ROYAL_FLUSH`).
- `kickers` — engine tiebreakers (rank values 2–14). Ports may use another internal encoding **if** all `compare` / foul outcomes match.
- `compare[].result` — `compareHands` sign: `-1` (a\<b), `0` tie, `1` (a\>b).

### `eval3.json` → `crossRow`

- `compareTopVsMiddle` — `compareHands(evaluate3(top), evaluate5(middle))` as −1/0/1.
- `wouldFoulTopVsMid` — `true` iff that compare is `> 0` (the top-vs-middle half of `isFouled`).

### `boards.json`

- `fouled` — `isFouled`.
- `royalties` — per-row + `total` (**0 total if fouled**).
- `royaltiesIfNotFouled` — raw `topRoyalties` / `middleRoyalties` / `bottomRoyalties` even when fouled (debug).
- `flQualify` — `qualifiesForFantasyland` (QQ+/trips, not fouled).
- `flStay` — map of profile id → `qualifiesForFantasylandRepeat`.
- `flCards` — map of profile id → `fantasylandCardCountProfile`.
- Profiles: `normal`, `cash` (alias of cash rules), `windfall`, `progressive`.

### `score_hu.json`

- `scoreA` / `scoreB` — `scoreHeadToHead` (zero-sum).
- `scoop` — `'A' \| 'B' \| null`; `scoopBonus` 3 or 0.
- One-foul: survivor gets `6 + own royalties`. Both-foul: `0-0`.

### `score_multi.json`

- `nets.A/B/C` — each player’s `scoreVsOpponents` vs the other two.
- `sumNets` — should be `0`.
- `pairwise` — each head-to-head component.

### `game_flow.json`

- `shuffledDeck` — full 52 after seeded Fisher–Yates.
- `initial` / `pineappleRounds` — deal order with `startIndex = (dealer+1) % n`.
- `flDealSizes` — cash/normal/windfall = 14; progressive QQ/KK/AA/trips = 14/15/16/17.

## How to validate a port

1. Parse cards with the encoding above.
2. For every `eval5` / `eval3` hand: category must match; prefer also matching kickers, but **require** all `compare` (and `crossRow`) results.
3. For every board: foul flag, royalty totals, `flQualify`, per-profile stay & card counts.
4. For every HU / multi case: net scores (and scoop / foul behaviour).
5. Optionally replay `game_flow` deal sizes/order with the same PRNG contract described in that file’s `meta`.

## Naming

Use only generic profile labels: **cash** (aka **normal**), **windfall**, **progressive**. Do not introduce real poker site or brand names in ports, tests, or docs.

