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
* [netfox.internals]
  * Shared utilities for the other addons
  * Included as dependency, no need to install separately

## Install

### Releases

Find the latest netfox under
[Releases](https://github.com/foxssake/netfox/releases)

Each release contains the addons, and a build of [Forest Brawl] for Windows and
Linux. Each addon has its dependencies packed with it - e.g.
*"netfox.extras.vx.y.z.zip"* also contains both *netfox* and
*netfox.internals*.

> Note: For releases before v1.1.1, a separate *".with-deps.zip"* version
> contains the addon and its dependencies, while the regular zips contain only
> the addon itself.

### Asset Library

Search for the addon name in Godot's AssetLib or download from the site:

* [netfox](https://godotengine.org/asset-library/asset/2375)
* [netfox.noray](https://godotengine.org/asset-library/asset/2376)
* [netfox.extras](https://godotengine.org/asset-library/asset/2377)

### Source

Download the [source] and copy the addons of your choice to your Godot project.

### Enable the addons

After adding *netfox* to your project, make sure to enable the addons in your
project settings. Otherwise, Godot will present you with errors about
undeclared identifiers.

## Upgrading

If you're upgrading from an older version of netfox, refer to the [upgrade
guide](docs/upgrading.md).

## Usage

See the [docs](https://foxssake.github.io/netfox/).

### Prototyping

To try your game online with [noray], a free to use instance is hosted at
`tomfol.io:8890`, the same instance used by [Forest Brawl].

You can use this [noray] instance to quickly test your games online, but is not
recommended for shipping games. The instance has configured limits, and no
uptime guarantees are made.

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

## Built with netfox

<table>
  <thead>
    <tr>
      <th>Logo</th>
      <th>Name</th>
      <th>Links</th>
    </tr>
  </thead>
  <tr>
    <td><img src="docs/assets/showcase/placeholder.svg"/></td>
    <td></td>
    <td></td>
  </tr>
</table>

Building something cool with netfox? Whether it's released or in progress, feel
free to open a PR!

## License

netfox is under the [MIT license](LICENSE).

Note that the repository contains assets made by other people as well. For
these cases, the relevant licenses can be found in the assets' directories.

## Issues

In case of any issues, comments, or questions, please feel free to [open an issue]!

## Contribution

Contributions are welcome! Please feel free to fork the repository and open a
PR. Ideally, your PR implements a single thing, optionally refers to an
existing issue, and follows the [GDScript style guide].

Please note that depending on the feature/fix you implement, the PR may need to
undergo changes, or in some cases, get rejected if it doesn't fit netfox's
intended feature set or vision.

If you feel like it, grant the netfox author(s) write permission to your fork,
so we can update the PR if needed.

If you're not sure if the PR would fit netfox or not, [open an issue] first,
mentioning that you'd be willing to contribute a PR.

Author(s) at the time of writing:

* @elementbound

[source]: https://github.com/foxssake/netfox/archive/refs/heads/main.zip
[Godot engine]: https://godotengine.org/
[noray]: https://github.com/foxssake/noray

[netfox]: addons/netfox
[netfox.noray]: addons/netfox.noray
[netfox.extras]: addons/netfox.extras
[netfox.internals]: addons/netfox.internals
[Forest Brawl]: examples/forest-brawl

[open an issue]: https://github.com/foxssake/netfox/issues
[GDScript style guide]: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
