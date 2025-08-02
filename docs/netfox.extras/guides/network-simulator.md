# Network Simulator

A developer tool for auto-connecting launched instances to each other and
simulating packet latency / loss

No need to run netem or Clumsy!

## How to Use

Add the NetworkSimulator node to your scene tree.

When your game launches one instance will start an ENetMultiplayerPeer server and
the rest will connect to it.

Either a server_created or client_connected signal will be fired which you can use
to boostrap your game code to.

![Signal Configuration](../assets/network-simulator.png)

## Configuration

_Hostname_ The address that will be hosting, usually 127.0.0.1 but you can change thise to \*
if you would like other machines on another network to also be able to join.

_Server Port_ Which port to listen on. A second server port with latency / loss will open one number higher if they are set to more than zero.

_Use Compression_ Will make use of ENET's range encoder to keep packet sizes down.

_Latency_ How many milliseconds to delay traffic by

_Packet loss_ What percentage chance of packets being dropped.
