# Frequently Asked Questions

This page covers some questions that many users may run into.

If you are not yet familiar with *netfox*, it is recommended to explore the
rest of the docs first. Doing so will provide the context for the answers
below.

Note that some questions may overlap, and their answers may refer to eachother.
This is intentional, to make it easier to find answers to your specific issue.

!!!question "Movement is glitchy, what do I do?"
    Make sure you're synchronizing every property used by `_rollback_tick()`,
    and that the same logic runs on the server and each client. Branching logic
    taking different paths may also be a cause.
    
    Glitchy movement happens when the client and server disagree on game state.
    The client in this case predicts the wrong position for an object, which then
    gets corrected by the server. This is seen as the object snapping into place.
    
    By applying the above suggestions, you're ensuring that your game code
    produces the same state, both as ground truth on the server, and as predicted
    by the clients.

!!!question "I've read about a feature in the docs, but it's not there in the addon!"
    Compare the docs version with the addon's version.

    You can select which version to read about in the docs, on the top left
    corner of the page. Using *"latest"* means you're reading about the latest
    features present in the repository. Some of these features may not yet be
    released.

!!!question "Help, something is not working!"
    Check if the issue is still present in the latest release, or in the latest
    main. If so, please let us know!

    The *latest release* refers to the version available on the [asset
    library], and in the [releases]. The *latest main* refers to the latest version
    available in the [repository]. The *latest release* is stable, but may contain
    some bugs that are already fixed on *latest main*. The *latest main* is the
    bleeding edge, meaning that it can be unstable.

    If the issue is still present, please let us know on [Discord], or by
    filing an [issue]!

[asset library]: https://godotengine.org/asset-library/asset?filter=netfox&category=&godot_version=&cost=&sort=updated
[releases]: https://github.com/foxssake/netfox/releases
[repository]: https://github.com/foxssake/netfox
[Discord]: https://discord.gg/xWGh4GskG5
[issue]: https://github.com/foxssake/netfox/issues

!!!question "What properties should I synchronize with RollbackSynchronizer?"
    Synchronize every property representing player input as Input properties.

    Synchronize every property read by, or written to in `_rollback_tick()` as
    State properties.

    The key concept to keep in mind, is that both server and client need to
    produce the same resulting game state as part of `_rollback_tick()`. Also keep
    in mind, that the game may rewind to an earlier state and resimulate from
    there.

    This means that any data used by your game logic needs to be synchronized,
    otherwise it might differ between peers, leading to differing outcomes,
    ultimately result in glitches. The most surefire way is to synchronize each
    piece of data used by the simulation.

!!!question "Can I remove and then re-add nodes to the scene tree?"
    When possible, avoid doing so.
    
    At the time of writing, it is not possible to reliably detect an other node
    being freed. This would be necessary for *RollbackSynchronizer*,
    *PredictiveSynchronizer* and *StateSynchronizer* to deregister nodes they
    manage.
    
    To this end, these nodes assumes that when they leave the scene tree, it is
    because they're being freed. So, when *RollbackSynchronizer* or any of the
    other *netfox* nodes exit the scene tree, they will deregister the nodes they
    manage.
    
    When these nodes re-enter the scene tree, *netfox* will consider them as a
    brand new node, not an already known node being reactivated.
    
    Note that this does not affect most use cases - just spawning a node, and
    then optionally freeing it sometime later is completely fine.

!!!question "What kind of data can netfox synchronize?"
    Data that is safe to use as RPC parameters is also safe with netfox. Other
    data types may work with [custom schemas]. Values passed by reference are best
    avoided.

    Types passed by value are safe to synchronize - e.g. `int`, `float`,
    `String`, `Transform3D`, etc.

    Values passed by reference are not recommended. Since *netfox* needs to
    keep a history, the value of the property is stored for every tick. For
    reference types, the history can only store a *reference* to the value, not the
    value itself. This means that the same reference may be stored for multiple
    ticks. This leads to values "leaking" between ticks, i.e. a modification set in
    a tick may show up in an earlier tick where it shouldn't have.

    These may be worked around either by duplicating the value for every tick
    in `_rollback_tick()`, or by writing a custom wrapper type that keeps a history
    for the value for every tick. These are only recommended for advanced users.

    The best approach, when available, is flattening the complex value into
    multiple, value-based properties. This approach also benefits more from
    diff states.

[custom schemas]: ./netfox/guides/network-schemas.md#implementing-a-custom-serializer

!!!question "When should I use RollbackSynchronizer vs. StateSynchronizer vs. MultiplayerSynchronizer?"
    Use `RollbackSynchronizer` for responsive behavior, e.g. player movement.
    Also use for objects that need to interact with other objects in rollback.

    Use `PredictiveSynchronizer` for objects that need to participate in
    rollback, but their state can be predicted by every peer on their own. For
    example, projectiles.

    Use `StateSynchronizer` for objects that don't need to respond instantly,
    but may still benefit from interpolation, diff states, schemas, or other netfox
    features. For example, NPCs with their positions interpolated. Often used
    for objects completely owned by the server.

    Use `MultiplayerSynchronizer` as a fallback, e.g. for data that doesn't
    need to be interpolated.

    Keep in mind that `MultiplayerSynchronizer` without a *Replication
    interval* or *Delta interval* will transmit data on every `_process()`,
    potentially increasing bandwidth. In contrast, *netfox* only transmits updates
    per network tick.

!!!question "Can I use MultiplayerSpawner with netfox and rollback?"
    Yes.

    In general, *netfox* tries to build on top of Godot's multiplayer tooling,
    instead of replacing them.

!!!question "Is netfox only usable for rollback?"
    <a id="is-netfox-only-usable-for-rollback"></a>
    No, rollback is one approach that *netfox* supports.

    For prototypes and certain game types, a client-authoritative approach
    works well. Many tools provided by *netfox* are useful here - time
    synchronization, interpolation, schemas, diff states, etc.

    The tools mentioned above are also useful regardless of networking
    approach, and can be reused for custom solutions. This includes
    productivity features, like auto-tiling windows, automatically setting up
    server and client connections on game start, and built-in latency simulation.

    In addition, support for other approaches are also planned for *netfox*.

!!!question "What kind of games can I build with netfox?"
    In general, most games can be expressed with rollback netcode, with a few
    notable exceptions. Rollback is also [not the only approach
    available](#is-netfox-only-usable-for-rollback) with *netfox*.

    Rollback is most often used for fighting games, where it's important that
    every input is processed and applied in the correct chronological order.

    Racing games that need collisions are good candidates for use with netfox's
    [physics support].

    FPS games are also doable with rollback, but favoring the shooter is not
    trivial to implement.

    RTS games specifically are not recommended with rollback. These games
    usually involve from dozens to possibly thousands of entities present in the
    game. Resimulating these entities requires lots of CPU time. Additionally,
    synchronizing all their properties through the network requires lots of
    bandwidth capacity. This makes rollback not a good fit for RTS games.

[physics support]: ./netfox.extras/guides/physics.md

!!!question "Can I use netfox with C#?"
    Yes, with [NetfoxSharp].

[NetfoxSharp]: https://github.com/CyFurStudios/NetfoxSharp/

!!!question "Is NetfoxSharp up to date?"
    NetfoxSharp keeps up to date with the latest netfox release. Unreleased
    features e.g. on latest `main` might not be available.

!!!question "Does netfox support android / iOS / web / ENet / etc.?"
    Yes.

    In general, *netfox* builds on top of Godot's multiplayer API, instead of
    replacing it. This means that it does not rely on any platform-specific functionality.

    It also uses Godot's built-in functions to transmit data. As long as Godot
    can transmit data on the desired platform or networking protocol, netfox should
    work fine.

!!!question "Can I use Resources in my game logic?"
    Yes.

    However, make sure to **not rely on shared resources** in your game logic
    implemented in `_rollback_tick()` or elsewhere if it doesn't make sense.

    For example, when implementing a crouching logic that modifies the player's
    `CollisionShape`, make sure that the `CollisionShape` **is not shared**,
    otherwise one player crouching will make every player crouch.

