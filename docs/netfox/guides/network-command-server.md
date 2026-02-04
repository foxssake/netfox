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
[SceneMultiplayer.send_bytes()]. This is an opt-in feature - if the game
is already using [SceneMultiplayer.send_bytes()], it needs to be aware
of commands, and must check each packet whether it's a command or one of its
own packets. To check if a packet is a command, use `is_command_packet()`.


[SceneMultiplayer.send_bytes()]: https://docs.godotengine.org/en/stable/classes/class_scenemultiplayer.html#class-scenemultiplayer-method-send-bytes
