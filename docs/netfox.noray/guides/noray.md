# Noray

Singleton providing [noray] integration.

*noray* is a backend application that orchestrates connection between players.
To do this, players send a connection request to *noray*, and in turn *noray*
sends the players' external addresses to eachother. It is then up to the
players to conduct a handshake process.

If the handshake fails, players can request a *relay* from *noray*. In these
cases, *noray* will receive data from one player and forward it to the other,
acting as a middle man.

## Identifiers

*noray* identifies players with two different IDs: OpenID and PrivateID.

*OpenID* is public, and can be shared with other players. This ID is used to
identify hosts when connecting to games.

*PrivateID* is only sent to the player it identifies and should **never** be
shared. Acts similar to a password, and is used to authorize commands.

## Relays and NAT Punchthrough

*noray* provides two methods of connecting players.

*NAT Punchthrough* relies on the NAT table. Players must continuously send data
to eachother until either two-way communication is established, or a timeout is
reached. For certain router setups, NAT punchthrough does not work.

See: [NAT Punch-through for Multiplayer Games]

For *relays*, *noray* allocates a specific port to a given player. When *noray*
receives data on this port, it will forward it as-is to the player. As long as
*noray* is accessible over the internet, relays should work reliably no matter
the router setup.

## Registering with noray

To start using *noray*, connect to a *noray* server, request IDs by
registering, and then register the remote address:

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

By calling `Noray.register_host()`, a request is sent to *noray*. Once a
response is received, both the `on_pid` and `on_oid` signals are fired, for
receiving the PrivateID and OpenID respectively.

The remote address must be registered so that *noray* knows where to direct
other players wanting to connect. This process also sets `Noray.local_port`,
which is where traffic can be received through *noray*.

## Starting a host

To host a game, start listening on *noray*'s local port:

```gdscript
var peer = ENetMultiplayerPeer.new()
var err = peer.create_server(Noray.local_port)

if err != OK:
  return false # Failed to listen on port
```

The rest is handled by *noray*.

## Starting a client

To connect to a game, send a request to *noray* with the host's OpenID.

```gdscript
var oid = "abcd1234"

# Connect using NAT punchthrough
Noray.connect_nat(oid)

# Or connect using relay
Noray.connect_relay(oid)
```

Once the request is sent, *noray* will send a message to both the client and
the host players to connect to each other. The actual connection is done by
handling signals.

> *Note* that *noray* provides no functionality to share OpenIDs. For
> development, you can display the OpenID in a textbox, letting players copy it
> and share over their preferred messaging app.

## Handling signals

When a connect message is received, the appropriate signal is fired.

*on_connect_nat* is fired to connect with NAT punchthrough.

*on_connect_relay* is fired to connect to a relay.

In both cases, a public address is passed to the signal handler, in the form of
an address string and a port. Handlers must conduct a handshake ( e.g. with
[PacketHandshake] ) and connect if successful.

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

[noray]: https://github.com/foxssake/noray
[NAT Punch-through for Multiplayer Games]: https://keithjohnston.wordpress.com/2014/02/17/nat-punch-through-for-multiplayer-games/
[PacketHandshake]: ./packet-handshake.md
