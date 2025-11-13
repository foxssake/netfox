# Logging

During runtime, it can be useful to print some diagnostic info to the console -
this is called logging. The netfox addons include a logging system to help with
debugging. This is useful when running the game locally, but also helps if
there's log files players can attach with their bug reports.

The system produces logs like this:

```
[DBG][@0][#1][_][netfox::NetworkPerformance] Network performance enabled, registering performance monitors
[DBG][@0][#1][_][netfox.extras::WindowTiler] Tiling with sid: f2682d1, uid: 17627261006193110
[DBG][@0][#1][_][netfox.extras::NetworkSimulator] Feature disabled
[DBG][@0][#1][_][netfox.extras::WindowTiler] Tiling as idx 0 / 1 - 17627261006193110 in ["17627261006193110"]
[DBG][@22][#1][_][netfox.extras::NetworkWeapon] Calling after fire hook for Bomb Projectile 5sswh7lcsgbq
[DBG][@27][#1][_][fb::Displacer] Created explosion at (2.027323, 1.500942, -14.99592)@26
[DBG][@34][#1][_][netfox.extras::NetworkWeapon] Calling after fire hook for Bomb Projectile u4h8opz52lin
[DBG][@46][#1][_][fb::Displacer] Created explosion at (4.892477, 1.500942, -14.83388)@45
[DBG][@46][#1][_][netfox.extras::NetworkWeapon] Calling after fire hook for Bomb Projectile 2u1d9n456yl1
[DBG][@57][#1][_][fb::Displacer] Created explosion at (4.814114, 1.500942, -14.57117)@56
```

This page will elaborate on how to produce your own logs, and what each part
means.

## Using the logger

The logging system can be accessed by creating an instance of `NetfoxLogger`.
Every logger has a name, and belongs to a module. Both of these can be
arbitrary strings, and are included in the logged messages.

Messages can be logged as different *logging levels*:

```gd
var logger := NetfoxLogger.new("my-game", "Player")
logger.trace("Detailed message")
logger.debug("Something happened")
logger.info("Hi!")
logger.warning("Couldn't connect")
logger.error("Game missing?")
```

To use string interpolation, you can also pass the template string and values
separately. This can be useful to avoid substituting the values in case the
message never gets printed because of filtering:

```gd
logger.trace("Adjusted clock by %.2fms, offset: %.2fms, new time: %.4fss", [nudge * 1000., offset * 1000., _clock.get_time()])
```

In the above example, there's a lot of data to be included in the message.
However, if trace logs are disabled, that data will never be substituted,
saving some processing time.

!!!tip
    This same logging system is used by netfox itself.

## Log levels

Each log message can belong to one of the following categories:

Error
:   Something goes irrecoverably wrong, or something that should never happen
    just happened

Warning
:   Something goes wrong, but can be handled

Info
:   Useful information on expected behaviour

Debug
:   Verbose messages, to help debug general code flow

Trace
:   Extremely verbose messages, to help follow the code flow to the smallest
    detail

Depending on your game, different logs may be needed. To accommodate this,
*netfox* can be configured in the [Project Settings](#settings) to omit certain
log messages.

Filtering based on log levels can also be configured from code. To set the
global log level, set `NetfoxLogger.log_level`. To configure the log level per
module, use the `NetfoxLogger.module_log_level` dictionary.

## Tags

Tags can be attached to the logging system. They provide pieces of information
that appear in each log message, for every logger.

By default, netfox provides a few tags, to help with debugging. These are, in
order:

Current tick
:   The current tick, as per `NetworkTime`

Peer ID
:   The currently active multiplayer peer's ID

Rollback status
:   Contains the current rollback stage, simulated tick, and resimulated tick
    interval.

    The stage can be `B` for before loop, `P` for prepare tick, `S` for
    simulate tick, `R` for record tick, and `A` for after loop.

    The current tick is in the form of `X|A>B`, meaning we're currently
    simulating tick X, in a loop going from tick A to tick B.

    Defaults to `_` if currently not in rollback.

!!!note
    These default tags are subject to change between releases.

Custom tags can be attached by calling `NetfoxLogger.register_tag()`. In this
sense, tags are callbacks that must return a single string, containing the tag
data to be logged.

This method takes a second, `priority` parameter. This priority is used to sort
them for logging - tags are printed from lowest priority to highest.

!!!warning
    Make sure to free your custom tags using `NetfoxLogger.free_tag()`. Not
    doing so might cause crashes. See [#433] for details.

## Settings

![Logging settings](../assets/logging-settings.png)

These settings control the *minimum* log level - e.g. if the log level is set
to *info*, only messages at or above the info level will be logged, namely
info, warning and error. If the setting is set to *all*, all messages are
logged.

Log levels can be controlled globally and per addon. A message will be logged
if it passes *both* logging level checks.

For example, if the *Log Level* setting is at *Warning* and the *Netfox Log
Level* is at *Info*, only warning and error messages are logged for netfox.
This happens because the *Log Level* is more restrictive than the *Netfox Log
Level* setting.

Note that you don't need to install all netfox addons for the logging settings
to work. If an addon is not installed, its log level setting is simply ignored.


[#433]: https://github.com/foxssake/netfox/issues/433
