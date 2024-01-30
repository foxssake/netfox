# NetworkPerformance

Provides [custom monitors] for measuring networking performance. Included as an
autoload.

## Enabling monitoring

By default, network performance monitoring is only enabled in debug builds and
when running from the editor.

Use the `netfox_noperf` feature tag to force disable network performance
monitors.

Use the `netfox_perf` feature tag to force enable network performance monitors.

These feature tags enable customization for each export preset.

## Performance monitors

### Network loop duration

*Network loop duration* measures the time spent in the [network tick loop].
Note that this includes time spent on the [rollback loop] as well.

This value is updated once for every tick loop, it is not reset to zero after
the loop has run. This means that you may get a non-zero reading, even if the
tick loop is currently not running.

### Rollback loop duration

*Rollback loop duration* measures the time spent in the last [rollback loop].
This includes all of its steps. 

The value of this monitor may be zero, if no players have joined, no nodes use
rollback, or rollback is disabled.

### Network ticks simulated

*Network ticks simulated* measures the number of ticks run in the last [network
tick loop]. If the game runs at a higher FPS than the network tickrate, this
value should be consistently one.

Higher, stable values mean that the game itself runs slower than the network
tickrate, and needs to catch up by running multiple ticks on each frame.

### Rollback ticks simulated

*Rollback ticks simulated* measures the number of rollback ticks run in the
last [rollback loop]. Generally, this denotes the age of the oldest input *or*
state received, depending on whether the game is running as a server or client.

The measurement is strongly correlated to network latency - the higher the
latency, the older the state and input packets will be upon arrival.

The more rollback ticks need to be simulated, the more work the rollback tick
has to do, which can negatively affect performance.

### Rollback tick duration

*Rollback tick duration* provides the average time spent simulating a single
tick in the last [rollback loop].

This can be useful to determine if the rollback tick duration comes from too
many ticks being simulated, or the individual ticks being expensive to
simulate ( or both ).

[custom monitors]: https://docs.godotengine.org/en/latest/classes/class_performance.html#class-performance-method-add-custom-monitor
[network tick loop]: ./network-time.md
[rollback loop]: ./network-rollback.md
