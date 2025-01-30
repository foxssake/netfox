# Netfox Sharp

!!!warning
    **[Netfox Sharp] is currently an experimental build and not ready for
    production. During this time, breaking changes may be introduced at any
    time.**

The [Netfox Sharp] addon is designed to bridge the gap between GDScript and C#
by allowing core netfox features to be accessed in C# without having to worry
about [Cross-Language Scripting] with GDScript directly.

### What Netfox Sharp Is

- A wrapper for netfox that uses the existing netfox codebase for its logic.
- A way to more conveniently call netfox logic in a C# environment.
- Partially compatible with existing codebases that use GDScript.

### What Netfox Sharp Isn't

- A standalone addon written entirely in C#.
- A perfect 1:1 translation. Due to quirks of netfox, some code will differ,
  detailed below.
- A wrapper for netfox.noray or netfox.extras. Support for either of those
  currently isn't planned, but may be considered based on interest.

## Getting Started

- Download the [Netfox Sharp] repo, and move the `netfox_sharp` and
  `netfox_sharp_internals` folders into the addons of a C#-enabled Godot
  project using the .NET version of Godot 4.x.
- Install the netfox addon. See the Netfox Sharp repo for details on which
  version of netfox you need.
- Build your project, then enable netfox and Netfox Sharp in your project
  settings.
- Restart Godot, and you've successfully set up Netfox Sharp!

## Differences Between Netfox And Netfox Sharp

Existing documentation for netfox should be easily translatable to Netfox Sharp
by following the below differences.

- Most changes follow Godot's rules for [Cross-Language Scripting], taking
  netfox as the base. In netfox, consider the following:

```gdscript
# The following example is a snippet of netfox code
func _ready():
    NetworkTime.before_tick_loop.connect(_gather)

func _gather():
    # Input gathering here
    pass

func _rollback_tick(delta, tick, is_fresh):
    # Rollback logic here
    pass
```

Whereas in Netfox Sharp:

```cs
// This is functionally identical Netfox Sharp code
public override void _Ready()
{
    // All netfox autoloads like NetworkTime are accessed through static members
    // in NetfoxSharp, to save on GetNode() calls and reduce clutter in the
    // project settings.

    // All members like BeforeTickLoop are in PascalCase, similar to Godot's C#
    NetfoxSharp.NetworkTime.BeforeTickLoop += Gather;
}

// As Gather is linked to a signal, it can be any naming convention.
private void Gather()
{
    // Input gathering here
}

// Since _rollback_tick isn't connected to a signal and is instead handled by
// netfox internally, netfox's naming convention must be followed.
public void _rollback_tick(double delta, long tick, bool isFresh)
{
   // Rollback logic here
}
```

- Nodes in the add mode menu have similar names to the GDScript version, but
  with 'Sharp' affixed, IE `RollbackSynchronizerSharp`. The GDScript versions
  of the nodes are also present in the add node menu. This is a limitation of
  how netfox interacts with Godot and cannot be removed.

# Other Notes
- `RollbackSynchronizerSharp`, `StateSynchronizerSharp`, and
  `TickInterpolatorSharp` create their own respective GDScript nodes, which are
  instanced as internal children nodes and should not be accessed.

[Cross-Language Scripting]: https://docs.godotengine.org/en/stable/tutorials/scripting/cross_language_scripting.html
[Netfox Sharp]: https://github.com/CyFurStudios/NetfoxSharp/
