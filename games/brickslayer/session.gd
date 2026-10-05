extends RefCounted
## Hand-off between the code trail and the game scene (static, survives scene changes).

## Lesson to play on the next game launch; -1 means the full game.
static var pending_step := -1
## Where the trail cursor was, so returning from "Play this step" lands there.
static var trail_lesson := 0
static var trail_block := 0
