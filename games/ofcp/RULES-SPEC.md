# OFCP Engine Rules Spec

Concise specification of the TypeScript engine at `tangentstorm/ofcp` (`main` @ `9d4f481`), as implemented in `src/`. This is what a GDScript port must match. Profile labels only: **cash** (aka **normal**), **windfall**, **progressive**.

Card encoding: `rank` + `suit`, e.g. `As`, `Td`, `2c`. Ranks `2–9,T,J,Q,K,A`. Suits `h,d,c,s`.

---

## 1. Deal sequence (Pineapple)

1. `createDeck()` builds 52 cards (suits × ranks in that nested order).
2. `shuffle()` Fisher–Yates (engine uses `Math.random`; golden `game_flow.json` uses seeded mulberry32 with the same shuffle structure).
3. `startIndex = (dealer + 1) % nPlayers`. Deal in that order.
4. **Initial deal:** 5 cards per player, unless the player is already in Fantasyland → deal `fantasylandCards` (typically 14; see profiles).
5. **Initial place:** non-FL players place all 5 onto the board (any legal row capacity). FL players place 13 and discard the rest (1 for 14-card FL, 2 for 15, etc.).
6. **Pineapple:** four rounds. Each non-complete player is dealt **3**, places **2**, discards **1**. FL players with a full board are skipped.
7. When every board is full (13 cards), enter scoring.

**Row sizes:** top 3, middle 5, bottom 5 (total 13).  
**Players:** 2 or 3.

Dealer advances by 1 after a hand **unless** any player remains in Fantasyland (dealer stays put).

---

## 2. Hand ranking

### 5-card (`evaluate5`) — middle & bottom

Categories (numeric enum used by the engine):

| # | Category |
|---|----------|
| 0 | HIGH_CARD |
| 1 | PAIR |
| 2 | TWO_PAIR |
| 3 | THREE_OF_A_KIND |
| 4 | STRAIGHT |
| 5 | FLUSH |
| 6 | FULL_HOUSE |
| 7 | FOUR_OF_A_KIND |
| 8 | STRAIGHT_FLUSH |
| 9 | ROYAL_FLUSH |

**Royal flush is its own category (9),** not merely a straight flush.

**Wheel:** `A-2-3-4-5` is a straight with high card **5** (not Ace).  
**Steel wheel:** same ranks suited → straight flush, high **5**.

Kickers are rank values (`2=2 … A=14`) in descending priority (pair rank, then side cards, etc.).

### 3-card top (`evaluate3`)

Only **HIGH_CARD**, **PAIR**, **THREE_OF_A_KIND**.  
**Straights and flushes do not count on top** (suited `A-K-Q` is still high card).

### Comparison (`compareHands`)

1. Higher category wins.
2. Else compare kickers pairwise until a difference.
3. Else tie.

**Quirk — unequal kicker lengths:** the loop uses `min(a.kickers.length, b.kickers.length)`. When foul-checking top (≤3 kickers) vs middle (up to 5), a top high-card `A-K-Q` **ties** a middle high-card `A-K-Q-x-y` (4th/5th kickers ignored). Top `A-K-Q` **beats** middle `A-K-J-x-y` → foul.

Ports need not use identical numeric kickers if all `compare` vectors in the golden files agree (−1 / 0 / 1).

---

## 3. Foul definition

Board must be complete (3+5+5). Incomplete → not fouled.

```
topRank  = evaluate3(top)
midRank  = evaluate5(middle)
botRank  = evaluate5(bottom)
fouled if compareHands(top, mid) > 0
       or compareHands(mid, bot) > 0
```

Equal rows are **legal** (not fouled).

*(GameMode `27` uses different foul rules; this port targets normal/cash scoring. See §8.)*

---

## 4. Royalties (normal mode; 0 if fouled)

### Top (3-card)

| Hand | Points |
|------|--------|
| Trips `222`…`AAA` | `rankValue − 2 + 10` → 10…22 |
| Pair `66`…`AA` | `rankValue − 5` → 1…9 |
| Pair `55` or lower / high card | 0 |

### Middle (5-card)

| Hand | Pts | Hand | Pts |
|------|-----|------|-----|
| Royal | 50 | Straight flush | 30 |
| Quads | 20 | Full house | 12 |
| Flush | 8 | Straight | 4 |
| Trips | 2 | else | 0 |

### Bottom (5-card)

| Hand | Pts | Hand | Pts |
|------|-----|------|-----|
| Royal | 25 | Straight flush | 15 |
| Quads | 10 | Full house | 6 |
| Flush | 4 | Straight | 2 |
| else | 0 |

`totalRoyalties` = sum of three rows, or **0 if fouled**.

---

## 5. Head-to-head scoring (`scoreHeadToHead`)

Zero-sum: `scoreA === -scoreB`.

| Situation | Result |
|-----------|--------|
| Both fouled | `[0, 0]` |
| A fouled, B clean | A gets `-(6 + B_royalties)`, B gets `+(6 + B_royalties)` |
| B fouled, A clean | symmetric |
| Neither fouled | see below |

Neither fouled:

1. Compare each row (top/mid/bot) with `compareHands` → +1 per row won (ties: 0).
2. Row points: `aWins - bWins`.
3. **Scoop bonus +3** if one player wins all three rows (so a clean scoop is +3 row pts +3 scoop = **+6** before royalties).
4. Add royalty differential: `+ (royA − royB)`.

Breakdown helper `scoringBreakdown` exposes per-row winners, scoop, and `netScore` (A’s perspective).

---

## 6. Multi-way scoring

`scoreVsOpponents(aiBoard, oppBoards)` = sum of `scoreHeadToHead(ai, opp)[0]` over opponents.

`scoreHand` in `game.ts` scores **every unordered pair** the same way and accumulates into each player’s running score.

**Foul pays both:** a fouled player loses the one-foul package to **each** clean opponent pairwise. Two fouled players exchange 0 with each other.

Sum of all players’ nets for a hand is 0.

---

## 7. Fantasyland

### Entry (`qualifiesForFantasyland`) — all profiles same

Not fouled, and top is **trips** or **pair QQ+**.

### Stay (`qualifiesForFantasylandRepeat` / profile)

Not fouled, and any enabled condition:

| Condition | cash / normal | windfall | progressive |
|-----------|---------------|----------|-------------|
| Trips+ on top | yes | yes | yes |
| Full house+ in middle | yes | **no** | yes |
| Quads+ on bottom | yes | yes | yes |

“`+`” means category ≥ threshold, so bottom straight-flush / royal also count as quads+ stay; middle quads / SF / royal count as FH+ stay (cash/progressive).

### Card counts (`fantasylandCardCountProfile`)

| Profile | Count |
|---------|-------|
| cash / normal / windfall | flat **14** |
| progressive | QQ→14, KK→15, AA→16, trips+→17; else default 14 |

Fouled board → `defaultFlCards` (14).  
*(Progressive counts are based on the qualifying top hand when computing next FL size; entry still requires QQ+/trips.)*

AI heuristic bonuses (`flEntryBonus`, `flTripsBonus`) differ by profile but do **not** affect rules scoring — ignore for the Godot rules port.

---

## 8. Profile comparison table

From `src/play-profile.ts`:

| | cash (`normal`) | cash alias | windfall | progressive |
|--|-----------------|------------|----------|-------------|
| id | `normal` | `cash` | `windfall` | `progressive` |
| FL stay trips top | ✓ | ✓ | ✓ | ✓ |
| FL stay mid FH+ | ✓ | ✓ | ✗ | ✓ |
| FL stay quads+ bot | ✓ | ✓ | ✓ | ✓ |
| Progressive FL cards | ✗ | ✗ | ✗ | ✓ |
| defaultFlCards | 14 | 14 | 14 | 14 |
| FL entry (QQ+/trips) | same | same | same | same |
| Scoring / royalties | same | same | same | same |

`resolvePlayProfile('cash')` → cash profile; unknown → normal.

---

## 9. GameMode `27` (out of scope for primary port)

Orthogonal to profile. Lowball middle (T-low qualify), different foul/royalty/FL rules (`isFouled27`, `middleRoyalties27`, etc.). Golden vectors target **normal** mode unless noted.

---

## 10. Engine quirks / deviations to watch

1. **Royal flush = category 9**, distinct from SF.
2. **Top ignores straights/flushes.**
3. **Foul compare uses min kicker length** → 3-card vs 5-card high-card ties possible (see golden `eval3.json` `crossRow` and boards `cross-kicker-*`).
4. **Scoop bonus is +3**, so foul indemnity is **6 + survivor royalties** (not 3).
5. **Equal rows do not foul.**
6. **Stay thresholds use `>=` category**, so SF/royal satisfy quads+/FH+ stay gates.
7. **FL entry is profile-independent;** only stay and card counts vary.
8. **Incomplete boards never foul** and royalties helpers still compute per-row if called directly; `totalRoyalties` zeroes on foul.
9. **Deck order:** `deal` takes from index 0 (`splice(0, n)`).
10. Suit order in `createDeck`: `h,d,c,s` × ranks `2…A`.

