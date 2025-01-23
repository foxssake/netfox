# Netfox Sharp

!!!warning
    **[Netfox Sharp] is currently an experimental build and not ready for production. During this time, breaking changes may be introduced at any time.**

The [Netfox Sharp] addon is designed to bridge the gap between GDScript and C# by allowing core netfox features to be accessed in C# without having to worry about [Cross-Language Scripting] with GDScript directly.

### What Netfox Sharp Is
- A wrapper for netfox that uses the existing netfox codebase for its logic.
- A way to more conveniently call netfox logic in a C# environment.
- Partially compatible with existing codebases that use GDScript.

### What Netfox Sharp Isn't
- A standalone addon written entirely in C#.
- A perfect 1:1 translation. Due to quirks of netfox, some code will differ, detailed below.
- A wrapper for netfox.noray or netfox.extras. Support for either of those currently isn't planned, but may be considered based on interest.

## Getting Started
- Download the [Netfox Sharp] repo, and move the netfox_sharp and netfox_sharp_internals folders into the addons of a C#-enabled Godot project. in the .NET version of Godot 4.x.
- Install the netfox addon, which can be found at the link above. See the Netfox Sharp repo for details on which version of netfox you need.
- Build your project, then enable netfox and Netfox Sharp in your project settings.
- Restart Godot, and you've successfully set up Netfox Sharp!

## Differences Between Netfox And Netfox Sharp
Existing documentation for netfox should be easily translatable to Netfox Sharp by following the below differences.

- Most changes follow Godot's rules for [Cross-Language Scripting], taking netfox as the base.
```puml
'Variables in GDScript use snake_case, while variables in C# use PascalCase,
'but otherwise use the same wording.

'GDScript
enable_prediction = true
'C#
EnablePrediction = true

'The same is true for methods and classes.

'GDScript
rollback_synchronizer.process_settings()
'C#
RollbackSynchronizer.ProcessSettings()
```
- To reduce clutter in the autoload tab and avoid unneeded calls to `GetNode()`, Netfox Sharp uses static instances for each of the core netfox autoloads in its own `NetfoxCore` autoload.
```puml
'GDScript
$NetworkTime.max_ticks_per_frame
'C#
NetfoxCore.NetworkTime.MaxTicksPerFrame
```
- Nodes in the add mode menu have similar names to the GDScript version, but with 'Sharp' affixed, IE `RollbackSynchronizerSharp`. The GDScript versions of the nodes are also present in the add node menu. This is a limitation of how netfox interacts with Godot and cannot be removed.


# Technical Differences
- `RollbackSynchronizerSharp`, `StateSynchronzierSharp`, and `TickInterpolatorSharp` create their own respective GDScript nodes, which are instanced as internal nodes which should not be accessed by any other means.

[Cross-Language Scripting]: https://docs.godotengine.org/en/stable/tutorials/scripting/cross_language_scripting.html
[Netfox Sharp]: https://github.com/CyFurStudios/NetfoxSharp/
