# NetworkCommandServer

Implements a simpler, lightweight alternative to RPCs. Provided as an autoload.

Commands consist of a single byte for ID, and the raw binary data. The ID lets
the receiving peer decide what to execute, with the binary data serving as the
input.

Being a simpler construct makes commands a good fit for regular, fundamental
operations. For example, commands internally are used for time synchronization,
or synchronizing state and input between peers.

Commands are, by default, transmitted over regular RPCs. To use less data,
commands can also be transmitted as raw packets, using
[SceneMultiplayer.send_bytes()]. This is an opt-in feature - if the game is
already using [SceneMultiplayer.send_bytes()], it needs to be aware of
commands, and must check each packet whether it's a command or one of its own
packets. To check if a packet is a command, use `is_command_packet()`.

## Implementing custom commands

Custom commands can be registered with the *NetworkCommandServer*, using
`register_command()`. This returns a *Command* object that provides a
convenient interface.

During registration, a callback must be provided, that will be ran when the
command is received.

Commands can be sent using its `send()` method.

```gdscript
@onready var cmd_message := NetworkCommandServer.register_command(handle_message, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)

func handle_message(sender: int, data: PackedByteArray) -> void:
  var message := data.get_string_from_utf8()
  print("#%d: %s" % [sender, message])

func _ready() -> void:
  cmd_message.send("Hello, world!".to_utf8_buffer())
```

!!!tip
    It is recommended to setup commands once, at game start. When registering
    commands from autoloads, make sure they run *after* netfox's autoloads.

## Differences compared to RPCs

Commands are a fundamentally simpler constructs compared to RPCs.

### Maximum 256 commands

Commands are limited to 256 indices - make sure to not register more than that.
Some commands are registered by netfox on startup as well.

This limitation also makes commands a poor fit for registering dynamically.
Dynamic registrations often mean registering commands as certain nodes or
objects are created. This, in turn, makes it difficult to place an upper bound
on the number of commands needed, which can conflict with this limitation.

### Commands are not tied to any node

Commands do not refer to any specific node or object in their content. They
only contain a command index. Even though the API encapsulates this into
*Command* objects, it is completely feasible to have different nodes handle the
same command on different peers ( if the game is built as different Godot
projects ).

### Commands do not track authority

Any peer can send any command to any other peer. It is the receiving peer's
responsibility to check whether the sender is allowed to send such a command or
not.

### Commands do not have arguments

To stay lightweight and to give maximum control, commands contain raw bytes
only, no arguments.

In general, this can be worked around by wrapping the arguments in an array and
converting it using [var_to_bytes()] and [bytes_to_var()].

However, for cases where bandwidth matters, this allows users to encode data in
a way that fits best.

## Settings

netfox ▸ General ▸ Use Raw Commands

: When enabled, netfox will transmit commands as raw packets, instead of RPCs.


[SceneMultiplayer.send_bytes()]: https://docs.godotengine.org/en/stable/classes/class_scenemultiplayer.html#class-scenemultiplayer-method-send-bytes
[var_to_bytes()]: https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-method-var-to-bytes
[bytes_to_var()]: https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-method-bytes-to-var
