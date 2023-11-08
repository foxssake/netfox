<p style="text-align: center">
  <img src="docs/assets/netfox.svg" />
</p>

# netfox

A set of addons for responsive online games with the [Godot engine].

## Features

* ⏲️  Consistent timing across multiple machines
* 🖥️ Supports client-server architecture
* 🧈 Smooth motion with easy-to-use interpolation
* 💨 Lag compensation with Client-side Prediction and Server-side Reconciliation
* 🛜 Bullet-proof connectivity with [noray] integration

## Overview

The package consists of multiple addons, each with different features:

* [netfox]
  * The core package, implements timing, rollback and other multiplayer
    features
  * *Start here*
* [netfox.noray]
  * Implements [noray] integration to establish connection between players
  * *Useful for online games*
* [netfox.extras]
  * Provides high-level, game-specific, convenience features built on top of
    netfox, like base classes for input management or weapons
  * *Check for reusable components for your game*

## Install

### Source

Download the [source] and copy the addons of your choice to your Godot project.

### Asset Library

TBA

## Usage

See the docs ( TBA ).

### Examples

#### Comparison sample

* [Single player](examples/single-player)
* [Simple example](examples/multiplayer-simple)
* [Example with netfox](examples/multiplayer-netfox)

To provide a short intro on how to get started with netfox, and how it fares
compared to built-in multiplayer tools, a simple demo was implemented as a
single-player game, which was ported to multiplayer using both a naive approach
and netfox.

#### Example game

* [Forest Brawl]

To provide examples of netfox usage in an actual game, [Forest Brawl] was
created and included specifically for this purpose.

It's a party game where an arbitrary amount of players compete by trying to
knock eachother off of the map.

## License

netfox is under the [MIT license](LICENSE).

Note that the repository contains assets made by other people as well. For
these cases, the relevant licenses can be found in the assets' directories.

## Issues

In case of any issues, comments, or questions, please feel free to [open an issue]!

[source]: https://github.com/foxssake/netfox/archive/refs/heads/main.zip
[Godot engine]: https://godotengine.org/
[noray]: https://github.com/foxssake/noray

[netfox]: addons/netfox
[netfox.noray]: addons/netfox.noray
[netfox.extras]: addons/netfox.extras
[Forest Brawl]: examples/forest-brawl

[open an issue]: https://github.com/foxssake/netfox/issues
