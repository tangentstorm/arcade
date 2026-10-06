# Gallery layout gotchas

How the card grid in `arcade/main.tscn` / `arcade/main.gd` (`_reflow_columns`) stays inside
the window. Each item below has broken the gallery at least once (#24, #25, #27).

Layout: full-rect root → `Margin/VBox` → `Header` + `%Scroll` (ScrollContainer) → `%GameList`
(GridContainer of cards). Only `%Scroll` scrolls, and only vertically.

## ScrollContainer: `horizontal_scroll_mode` 3, not 0

- `SCROLL_MODE_DISABLED` (0) means "no horizontal scrolling", so the ScrollContainer takes its
  child's **min width as its own**. If the grid is a bit too wide, the whole VBox grows past the
  window.
- `SCROLL_MODE_SHOW_NEVER` (3) still scrolls (with no bar) but does **not** pass the child's
  min width up. This is the one we want: no horizontal bar, and a grid that is too wide gets
  clipped inside the scroll instead of growing the page.
- `vertical_scroll_mode = 1` (AUTO). `clip_contents = true` on the scroll.

## Leave room for the vertical scrollbar

The vertical bar sits **inside** the ScrollContainer's width. If you size the grid to exactly
`_scroll.size.x`, the bar shows up and the grid ends up `bar` px (≈8) too wide. `_reflow_columns`
always subtracts `get_v_scroll_bar().get_combined_minimum_size().x`, even when the bar is
hidden. That way the column count doesn't flip when the bar shows or hides.

## Never bump cells up to `CARD_MIN_W`

`CARD_MIN_W` only decides **how many columns** fit. Cell width is then
`floor((avail - gap*(cols-1)) / cols)`, and on narrow windows (1 column) it can be **smaller**
than `CARD_MIN_W`. Do not `max(cell_w, CARD_MIN_W)`: that made the grid wider than the window
and the page scrolled sideways (#24). Floor the width as well, so rounding can't add a pixel.

## `grow_horizontal = 2` (both) clips on both sides

The root and `Margin` are full-rect with `grow_horizontal = GROW_DIRECTION_BOTH`. When a child's
min width is bigger than the window, the control grows **from the center** instead of
off to the right. The header and the first column get cut off on the left, and nothing scrolls
to bring them back (#25). If the left edge goes missing, look for a min width that is too big,
not for an offset bug. Things that can force one: the grid (see mode 0 above), or the header
(the title/subtitle use `text_overrun_behavior` ellipsis and the hint autowraps for this reason).

## Ratchet: min width feeds back into `avail`

With mode 0 the scroll's width follows the grid, and the grid is sized from the scroll's width.
So every resize could only grow it: one run reached 2468 px / 9 columns in a 1280 px window
and never shrank back. `_list.custom_minimum_size` stays `(0, 0)` and the cards use
`SIZE_SHRINK_BEGIN` so no min width comes from the grid itself.

## Re-read the scroll's min size after a reflow

`_reflow_columns` runs from `_scroll.resized`, which happens during the scroll's own layout.
The card min-size changes it makes don't refresh the ScrollContainer's cached child size, so the
vertical bar's range stays **one resize behind**. After shrinking from 2560 to 1280 wide the bar
stopped at 1024 px of a 2244 px grid, so the bottom rows couldn't be reached. Going down to
fewer columns could also leave no bar at all on a grid taller than the view. That's why
`_reflow_columns` ends with `_scroll.update_minimum_size()` (#27).

## Tests

`tools/test_gallery_layout.gd` (headless) runs each card-count fixture through six window sizes:
real registry, empty (0), one, few (3), many (24), overflow (120). The sizes go large → small →
large, so a ratchet would show up. For every fixture and size it checks:

- header and scroll stay inside the window, with no horizontal bar
- the grid plus the vertical bar fits in the scroll, and no card goes past it
- the card count matches the fixture
- a grid taller than the view has a vertical bar, and the bar's range covers the whole grid
  (the overflow fixture always needs the bar)

```bash
/workspace/tools/godot4 --headless --path . --import    # fresh checkout / worktree first
/workspace/tools/godot4 --headless --path . --script res://tools/test_gallery_layout.gd
# or, with evidence + log scan:  .cursor/skills/verify-arcade/helpers/layout.sh [--shots]
```

Fixtures reuse real cards (`main.gd` `_make_card` / `_update_card`) and cycle through registry ids.
They don't add any test-only hooks to the shipped scene.
