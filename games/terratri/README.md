# terratri

Terratri is Adam "Atomic" Saltsman's minimalist territory-capture game. Michal J
Wallace first built it online in 2011 (Python/GAE) and rewrote it in 2026 as
TypeScript ([tangentstorm/terratri](https://github.com/tangentstorm/terratri)).
Two pawns start on opposite sides of a 5×5 board. Each turn you get 2 actions:
move one square, or fortify a square once you hold 5 empty squares. You can bank
your second action for a bonus action on a later turn. The first player with 5
forts wins.

- **Direct:** playable. Hotseat 2-player on one screen, with the rules ported
  line by line to GDScript and checked against golden playouts from the TS code.
  See [PORT.md](PORT.md).
- **Enhanced:** planned.

Game design by Adam Saltsman. The implementation is MIT (see `source/LICENSE`).
