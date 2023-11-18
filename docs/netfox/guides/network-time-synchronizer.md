# NetworkTimeSynchronizer

Synchronizes time towards a target peer. Provided as an autoload.

Synchronization is run periodically in a loop. During synchronization, the
*NetworkTimeSynchronizer* measures the roundtrip to the target peer, assumes
latency is half of the roundtrip, and adds the latency to the latest time
received from the target peer.

To estimate the roundtrip time, it sends multiple ping messages to the target
peer, measuring how much time it takes to get a response. Measurements that are
too far from the average are rejected to filter out latency spikes.

Further reading: [Time, Tick, Clock Synchronisation]

Most of the time you shouldn't need to interface with this class directly,
instead you can use [NetworkTime].

[Time, Tick, Clock Synchronisation]: https://daposto.medium.com/game-networking-2-time-tick-clock-synchronisation-9a0e76101fe5
[NetworkTime]: ./network-time.md
