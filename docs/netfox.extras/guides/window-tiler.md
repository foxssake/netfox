# WindowTiler

A developer convenience feature that automatically tiles the launched windows
when working from the editor.

![Window Tiler](../assets/window-tiler.gif)

## Limitations

### Borderless mode on Linux

Setting window position and size works inconsistently under Linux at the time
of writing. Your mileage may vary based on your desktop environment and
distribution.

In case the windows don't tile properly with *Borderless* enabled, disabling it
is a fallback.

### Window decorations

At the time of writing, there is no known and consistent way to compensate for
window decoration size and offset. In practice, this means that windows may
slightly overlap.

## Configuration

*Auto Tile Windows* Enables auto tiling from editor launches.

*Screen* Which screen number to move and tile the windows to.

*Borderless* Enable borderless mode to make the most out of the screen real
estate.

