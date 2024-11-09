# NetworkTimeSynchronizer

Synchronizes time to the host remote. Provided as an autoload.

Synchronization is done by continuously pinging the host remote, and using
these samples to figure out clock difference and network latency. These are
then used to gradually adjust the local clock to keep in sync.

## The three clocks

The process distinguishes three different clock concepts:

The *Remote clock* is the clock being synchronized to, running on the host peer.

The *Reference clock* is a local clock, running on the client, that is getting
adjusted to match the Remote clock as closely as possible. This clock is
unsuitable to use for gameplay, as it being regularly adjusted can lead to
glitchy movement.

The *Simulation clock* is also a local clock, and is being synchronized to the
Reference clock. The Simulation clock is guaranteed to only move forwards in
time. It drives the [Network tick loop].

Most of the time you shouldn't need to interface with this class directly,
instead you can use [NetworkTime].

## Synchronizing the Reference clock

Synchronization is done by regularly taking samples of the remote clock, and
deriving roundtrip time and clock offset from each sample. These samples are
then combined into a single set of stats - offset, roundtrip time and jitter.

*Offset* is the difference to the remote clock. Positive values mean the remote
clock is ahead of the reference clock. Negative values mean that the remote
clock is behind the reference clock. May also be called theta.

*Roundtrip time* is the time it takes for data to travel to the remote and then
back over the network. Smaller roundtrip times usually mean faster network
connections. May also be called delay or delta.

*Jitter* is the amount of variation in measured roundtrip times. The less
jitter, the more stable the network connection usually.

These stats are then used to get a good estimate of the current time on the
remote clock. The remote clock estimate is then used to slowly adjust ( nudge )
the reference clock towards the remote clock's value.

This is done iteratively, to avoid large jumps in time, and to - when possible
- only go forward in time, not backwards.

When the offset gets too significant, it means that the clocks are excessively
out of sync. In these cases, a panic occurs and the reference clock is reset.

This process is inspired by the [NTPv4] RFC.

## Synchronizing the Simulation clock

While the Reference clock is in sync with the Remote clock, its time is not
linear - it is not guaranteed to advance monotonously, and technically it's
also possible for it to move backwards. This would lead to uneven tick loops (
e.g. sometimes 3 ticks in a single loop, sometimes 1, sometimes 5), and by
extension, uneven and jerky movement.

To counteract the above, the Simulation clock is introduced. It is synced to
the Reference clock, but instead of adjusting it by adding small offsets to it,
it is *stretched*.

Whenever the Simulation clock is ahead of the Reference clock, the it will
slightly slow down, to allow the Reference clock to catch up. When the
Reference clock is ahead of the Simulation clock, it will run slightly faster
to catch up with the Reference clock.

These stretches are subtle enough to not disturb gameplay, but effective enough
to keep the two clocks in sync.

The Simulation clock is handled by [NetworkTime].

## Characteristics

The above process works well regardless of latency - very similar results can
be achieved with 50ms latency as with 250ms.

Synchronization is more sensitive to jitter. Less stable network connections
produce more varied latencies, which makes it difficult to distinguish clock
offsets from latency variations. This in turn leads to the estimated clock
offset changing more often, which results in more clock adjustments.

[Network tick loop]: ./network-time.md#network-tick-loop
[NetworkTime]: ./network-time.md
[NTPv4]: https://datatracker.ietf.org/doc/html/rfc5905

