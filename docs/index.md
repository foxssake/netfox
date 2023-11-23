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

## Getting started

Netfox consists of three addons:

* netfox
    * The core package, implements timing, rollback and other multiplayer
      features
    * *Start here*
* netfox.noray
    * Implements [noray] integration to establish connection between players
    * *Useful for online games*
* netfox.extras
    * Provides high-level, game-specific, convenience features built on top of
      netfox, like base classes for input management or weapons
    * *Check for reusable components for your game*

Download the addons needed from the latest release ( TBA ), or grab the
[source] and copy the addons folder to your project.

With netfox added to your project, you're ready to take advantage of its
features, as outlined in the tutorials.

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

[Godot engine]: https://godotengine.org/
[noray]: https://github.com/foxssake/noray
[source]: https://github.com/foxssake/netfox/archive/refs/heads/main.zip
