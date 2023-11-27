<p style="text-align: center">
  <img src="assets/netfox.svg" />
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

### Releases

Find the latest netfox under
[Releases](https://github.com/foxssake/netfox/releases)

Each release contains the addons, and a build of [Forest Brawl] for Windows and
Linux.

In cases of dependencies, a *".with-deps.zip"* version is included as well,
which contains all the dependencies of the addon. For example, *netfox.noray*
depends on *netfox*, so *"netfox.noray.v1.x.y.with-deps.zip"* includes both
*netfox.noray* and *netfox*.

### Asset Library

Search for the addon name in Godot's AssetLib or download from the site:

* [netfox](https://godotengine.org/asset-library/asset/2375)
* [netfox.noray](https://godotengine.org/asset-library/asset/2376)
* [netfox.extras](https://godotengine.org/asset-library/asset/2377)

### Source

Download the [source] and copy the addons of your choice to your Godot project.

## About this documentation

These pages assume that you are familiar with both Godot, its multiplayer
capabilities, and building multiplayer games in general. Missing any of these
might make your reading experience more difficult than preferred.

Some links to get you up to speed:

* [Godot Engine docs](https://docs.godotengine.org/en/stable/index.html)
* [Godot Engine High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
* [Networking for Physics Programmers](https://www.gdcvault.com/play/1022195/Physics-for-Game-Programmers-Networking)

## About the tutorials

The tutorials are intended to get you started fast, but don't explain much of
how things work. For that, refer to the guides.

[netfox]: https://github.com/foxssake/netfox/tree/main/addons/netfox
[netfox.noray]: https://github.com/foxssake/netfox/tree/main/addons/netfox.noray
[netfox.extras]: https://github.com/foxssake/netfox/tree/main/addons/netfox.extras
[Forest Brawl]: https://github.com/foxssake/netfox/tree/main/examples/forest-brawl

[Godot engine]: https://godotengine.org/
[noray]: https://github.com/foxssake/noray
[source]: https://github.com/foxssake/netfox/archive/refs/heads/main.zip
