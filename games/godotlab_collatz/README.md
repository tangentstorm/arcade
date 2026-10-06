# godotlab_collatz

Status: **Direct + Enhanced playable**. Source: godotlab/collatz (Godot 3). See [PORT.md](PORT.md).

Click the bits on the red 16-bit register to enter a number. **Space**/**Enter** applies one Collatz step
(even → shift right, odd → 3n+1), **R** runs to 1, and **C** clears. The Step, Run, and Clear buttons do the same. Esc opens the arcade pause.

- **Enhanced:** playable. A self-fitted 1280×720 stage over the same Direct `game.tscn`: bit glow and flip juice, a shift / carry-ripple animation for each step, a last-step breakdown, a log₂ trajectory chart, reached-1 and overflow juice, and **P** presets (27, 7, 97, 255, 703).
