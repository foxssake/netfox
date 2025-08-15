# RewindableRandomNumberGenerator

A random number generator that can be used inside the [rollback tick loop].

An important point for writing code that works well in rollback is that it
behaves the same given the same circumstances, no matter how many times it's
run. It also must behave the same no matter which peer is running it.

Godot's built-in [RandomNumberGenerator] is not aware of rollback, so it will
consistently return different numbers for each tick, and potentially on each
peer.

To fix that, the *RewindableRandomNumberGenerator* generates the same random
sequences on each peer, and for each tick.

It implements most of the same methods, so it's close to a drop-in replacement.

## Creating the generator

The *RewindableRandomNumberGenerator* requires a seed upon initialization. This
seed must be the same on all peers.

!!!warning
    If two *different* RNGs use the *same* seed, they will also generate the
    same random numbers. Make sure that you use different seeds for different
    objects.

For RNG's used by singletons, hard-coding different seed values is a very
simple approach:

```gd
var rng := RewindableRandomNumberGenerator.new(15)
```

If these objects also have names or similar, consistent identifiers, a simple
hash works well too:

```gd
var rng := RewindableRandomNumberGenerator.new(hash("Exit beacon"))
```

For dynamically spawned objects, or just to avoid the possibility of a human
error, the node path can be hashed:

```gd
var rng := RewindableRandomNumberGenerator.new(hash(get_path()))
```

This assumes that the same node will be spawned under the same path on all
peers, which is also a requirement for RPCs to work.

## Generating random numbers

The *RewindableRandomNumberGenerator* can be used in the same way as Godot's
built-in [RandomNumberGenerator]. All the per-peer and per-tick consistency is
ensured under the hood:

```gd
var rng := RewindableRandomNumberGenerator.new(0)

var dice_roll := rng.randi_range(1, 6)
```


[rollback tick loop]: ../../netfox/guides/network-rollback.md
[RandomNumberGenerator]: https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html
