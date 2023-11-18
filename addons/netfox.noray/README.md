# netfox.noray

Bulletproof your connectivity with [netfox]'s [noray] integration!

## Features

* 🤝 Establish connectivity using NAT punchthrough
  * Uses [noray] for orchestration
  * Implements a full UDP handshake
* 🛜 Use [noray] as a relay
  * Useful in cases where NAT punchthrough fails
  * If you can see this repo, you probably can connect through [noray]

## Install

### Source

Download the [source] and copy the netfox.noray addon to your Godot project.

> Note: this addon depends on netfox, make sure to include it as well in your project.

### Asset Library

TBA

## Usage

See the [docs].

For a full example, see [noray-bootstrapper.gd].

## License

netfox.noray is under the [MIT license](LICENSE).

## Issues

In case of any issues, comments, or questions, please feel free to [open an issue]!

[netfox]: https://github.com/foxssake/netfox
[source]: https://github.com/foxssake/netfox/archive/refs/heads/main.zip
[noray]: https://github.com/foxssake/noray
[docs]: https://foxssake.github.io/netfox/netfox.noray/guides/noray/
[noray-bootstrapper.gd]: ../../examples/shared/scripts/noray-bootstrapper.gd
