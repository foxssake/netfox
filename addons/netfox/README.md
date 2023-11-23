# netfox

The core addon of [netfox], providing responsive multiplayer features for the
[Godot Engine].

## Features

* ⏲️  Synchronized time
  * Runs game logic at a fixed, configurable tickrate
  * Time synchronized to game host
* 🧈 State interpolation
  * Render 24fps tickrate at buttery smooth 60fps or more
  * Add a `TickInterpolator` node and it just works
* 💨 Lag compensation with CSP
  * Implement responsive player motion with little to no extra code
  * Just use the `RollbackSynchronizer` node for state synchronization

## Install

See the root [README](../../README.md).

## Usage

See the [docs](https://foxssake.github.io/netfox/).

## License

netfox is under the [MIT license](LICENSE).

## Issues

In case of any issues, comments, or questions, please feel free to [open an issue]!

[netfox]: https://github.com/foxssake/netfox
[source]: https://github.com/foxssake/netfox/archive/refs/heads/main.zip
[Godot engine]: https://godotengine.org/
[open an issue]: https://github.com/foxssake/netfox/issues
