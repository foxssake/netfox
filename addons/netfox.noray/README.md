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

See the docs ( TBA ).

For a full example, see [noray-bootstrapper.gd].

### Setup

All players must connect to noray and register:

```gdscript
var host = "some.noray.host"
var port = 8890
var err = OK

# Connect to noray
err = await Noray.connect_to_host(host, port)
if err != OK:
  return err # Failed to connect

# Register host
Noray.register_host()
await Noray.on_pid

# Register remote address
# This is where noray will direct traffic
err = await Noray.register_remote()
if err != OK:
  return err # Failed to register
```

Once this process is done, noray has assigned two ID's to the player: an OpenID
and a PrivateID. The OpenID is used to identify the player, e.g. when others
want to connect, and is freely shareable. The PrivateID is used by the client
to identify itself towards noray, and should not be shared.

### Starting a host

To start hosting, use noray's registered local port:

```gdscript
var peer = ENetMultiplayerPeer.new()
var err = peer.create_server(Noray.local_port)

if err != OK:
  return false # Failed to listen on port
```

### Starting a client

To connect to someone using noray, the target player's OpenID is needed. Note
that noray itself does not provide any facilities to share these.

For testing, simply displaying the OID for the player and sharing it over
messaging apps can work as a temporary solution.

```gdscript
var oid = "abcd1234"

# Connect using NAT punchthrough
Noray.connect_nat(oid)

# Or connect using relay
Noray.connect_relay(oid)
```

The above two calls will return instantly, since they only send a request to
noray. The actual connection will be orchestrated by noray, and games must
implement the related callbacks.

### Implementing callbacks

When noray receives a connection request ( either over NAT or relay ), it will
ask both participants to do a handshake. Once this handshake is successful,
players may connect to eachother.

This is why callbacks must be implemented.

Client example:

```gdscript
func _ready():
  Noray.on_connect_nat.connect(_handle_connect)
  Noray.on_connect_relay.connect(_handle_connect)

func _handle_connect(address: String, port: int) -> Error:
  # Do a handshake
  var udp = PacketPeerUDP.new()
  udp.bind(Noray.local_port)
  udp.set_dest_address(address, port)

  var err = await PacketHandshake.over_packet_peer(udp)
  udp.close()

  if err != OK:
    return err

  # Connect to host
  var peer = ENetMultiplayerPeer.new()
  err = peer.create_client(address, port, 0, 0, 0, Noray.local_port)

  if err != OK:
    return err

  return OK
```

> *Note:* Make sure to **always** specifiy the local port for the client - this
> is the only port noray recognizes, and failing to specify it will result in
> broken connectivity.

Host example:

```gdscript
func _ready():
  Noray.on_connect_nat.connect(_handle_connect)
  Noray.on_connect_relay.connect(_handle_connect)

func _handle_connect(address: String, port: int) -> Error:
  var peer = get_tree().get_multiplayer().multiplayer_peer as ENetMultiplayerPeer
  var err = await PacketHandshake.over_enet(peer.host, address, port)

  if err != OK:
    return err

  return OK
```

> *Note:* The host handshake is a bit different, as it can't receive manual
> packets, only send them. So it assumes that the target is always responsive,
> and just blasts them with a bunch of packets. If the target is indeed
> responsive, it can connect. If not, nothing happens, as expected.

## License

netfox.noray is under the [MIT license](LICENSE).

## Issues

In case of any issues, comments, or questions, please feel free to [open an issue]!

[netfox]: https://github.com/foxssake/netfox
[source]: https://github.com/foxssake/netfox/archive/refs/heads/main.zip
[noray]: https://github.com/foxssake/noray
[noray-bootstrapper.gd]: ../../examples/shared/scripts/noray-bootstrapper.gd
