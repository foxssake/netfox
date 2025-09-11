# Network Simulator

During testing, it is crucial to test your game under realistic network
conditions, including latency and potentially packet loss.

This can be simulated using [clumsy], [netem], or with *netfox*'s
*NetworkSimulator*. It auto-connects instances when launched from the editor,
and simulates various network configurations.

## How to Use

Add the *NetworkSimulator* node to your scene tree.

When your game launches one instance will start an [ENetMultiplayerPeer] server
and the rest will connect to it.

Either a `server_created` or `client_connected` signal will be fired which you
can use to bootstrap your game code to.

![Signal Configuration](../assets/network-simulator.png)

## Configuration

Hostname
: The hosting address. Usually `127.0.0.1` but can be changed to `*`, if you
want other machines to be able to join.

Server Port
: Which port to listen on. A second server port with latency / loss will open
one number higher if they are set to more than zero.

Use Compression
: Will make use of ENET's range encoder to keep packet sizes down.

Latency
: Traffic delay, in milliseconds.

Packet loss
: What percentage of packets will to drop, simulating bad network conditions.


[clumsy]: https://jagt.github.io/clumsy/
[netem]: https://man7.org/linux/man-pages/man8/tc-netem.8.html
[ENetMultiplayerPeer]: https://docs.godotengine.org/en/4.1/classes/class_enetmultiplayerpeer.html
