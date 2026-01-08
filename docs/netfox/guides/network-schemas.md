# Network Schemas

By default, *netfox* uses Godot's [Binary serialization API] to serialize data
before transmitting it over the network. This is designed to work under various
circumstances, with various data types, without knowing anything about them in
advance.

However, during development, developers often have knowledge about the
individual properties, such as their type and possible range of values. In
addition, some values may be less important as others, and thus can accept some
loss of precision.

Schemas enable developers to specify how each property should be serialized,
allowing them to use this knowledge to reduce packet sizes, and thus bandwidth
usage.

## Lossless vs. lossy

Most serializers are either lossless or lossy. This section gives a short
theoretical introduction on what each means and when are they useful.

### Lossless compression

When the same amount of information can be represented with less data ( bytes
), it is *lossless compression*.

For example, to represent a 2D normal vector, we do not need to serialize both
of its component ( x, y ). Since we know the vector's length to be 1 by
definition, we can store the vector's angle compared to predetermined reference
vector. From that, we can completely reconstruct the original vector on
deserialization.

Another example is when the range of values the vector can take on is much
smaller than its underlying datatype supports. For example, an inventory where
items can't stack beyond 99. Instead of defaulting to a 64 bit integer, it is
sufficient to serialize this data as a 8 bit integer. That is 1/8th of the
original data, while still perfectly representing the range of values needed.

Lossless compression is an excellent tool, since the same information is kept,
but with less data usage. Unfortunately, lossless compression is not feasible
for every property.

### Lossy compression

If some information is lost when using less data ( bytes ) to represent a
value, it is *lossy compression*. This can be useful in cases where the benefit
of reduced packet size outweighs the drawbacks of lost information.

For example, movement vectors for NPCs may be serialized as half precision
floats, instead of the default single precision. Since players don't directly
control NPC's, they won't notice any difference between their original input
and what was serialized.

While lossy compression can be a useful tool, it is important to judge whether
the loss of information or precision does not detract too much from the game
experience.

## Registering a schema

Both [RollbackSynchronizer] and [StateSynchronizer] expose a `set_schema()`
method, that can be used to register the schema used for transmitting
properties over the network. This method takes a dictionary, with the keys
being property path strings, and the values being serializers:

```gdscript
	rollback_synchronizer.set_schema({
		":transform": NetworkSchemas.transform3f32(),
		":velocity": NetworkSchemas.vec3f32(),
		":speed": NetworkSchemas.float32(),
		":mass": NetworkSchemas.float32(),
		
		"Input:movement": NetworkSchemas.vec3f32(),
		"Input:aim": NetworkSchemas.vec3f32()
	})
```

## Built-in serializers

`NetworkSchemas` provides many built-in serializers in the form of static
methods. Each supported type has multiple serializers for different sizes.

While many serializers are usable as-is, there are some generic ones that take
other serializers as arguments. For example, `vec3t()` serializes a Vector3,
and using the serializer passed to it to save each component of the vector.
This way, `vec3t(float16())` will save 3 half-precision floats, ending up with
6 bytes of data, while `vec3t(float32())` will save 3 single-precision floats,
ending up with 12 bytes.

!!!note
    Many built-in serializers use half-precision floats. These are only
    supported in Godot 4.4 and up. Earlier versions fall back to
    single-precision floats.

    For example, `float16()` may fall back to `float32()`, `vec2f16()` to
    `vec2f32()`, etc.

### Algebraic types

| Type                  | Methods                                                 | Size                                                               |
|-----------------------|---------------------------------------------------------|--------------------------------------------------------------------|
| Booleans              | `bool8()`                                               | 1 byte                                                             |
| Signed integers       | `int8()`, `int16()`, `int32()`, `int64()`               | 1, 2, 4, or 8 bytes                                                |
| Unsigned integers     | `uint8()`, `uint16()`, `uint32()`, `uint64()`           | 1, 2, 4, or 8 bytes                                                |
| Floats                | `float16()`, `float32()`, `float64()`                   | 2, 4, or 8 bytes                                                   |
| Vector2               | `vec2f16()`, `vec2f32()`, `vec2f64()`                   | 4, 8, or 16 bytes                                                  |
| Vector3               | `vec3f16()`, `vec3f32()`, `vec3f64()`                   | 6, 8, or 24 bytes                                                  |
| Vector4               | `vec4f16()`, `vec4f32()`, `vec4f64()`                   | 8, 16, or 32 bytes                                                 |
| Quaternion            | `quatf16()`, `quatf32()`, `quatf64()`                   | 8, 16, or 32 bytes                                                 |
| Transform2D           | `transform2f16()`, `transform2f32()`, `transform2f64()` | 12, 24, or 48 bytes                                                |
| Transform3D           | `transform3f16()`, `transform3f32()`, `transform3f64()` | 24, 48, or 96 bytes                                                |

### Compressed types

| Type                  | Methods                                                 | Size                                                               |
|-----------------------|---------------------------------------------------------|--------------------------------------------------------------------|
| Numbers in `[0, 1]`   | `ufrac8()`, `ufrac16()`, `ufrac32()`                    | 1, 2, or 4 bytes                                                   |
| Numbers in `[-1, +1]` | `sfrac8()`, `sfrac16()`, `sfrac32()`                    | 1, 2, or 4 bytes                                                   |
| Degrees               | `degrees8()`, `degrees16()`, `degrees32()`              | 1, 2, or 4 bytes                                                   |
| Radians               | `radians8()`, `radians16()`, `radians32()`              | 1, 2, or 4 bytes                                                   |
| Normalized 2D vectors | `normal2f16()`, `normal2f32()`, `normal2f64()`          | 2, 4, or 8 bytes                                                   |
| Normalized 3D vectors | `normal3f16()`, `normal3f32()`, `normal3f64()`          | 4, 8, or 16 bytes                                                  |

### Generic types

| Type                  | Methods                                                 | Size                                                               |
|-----------------------|---------------------------------------------------------|--------------------------------------------------------------------|
| Vector2               | `vec2t()`                                               | `2 * sizeof(component)`                                            |
| Vector3               | `vec3t()`                                               | `3 * sizeof(component)`                                            |
| Vector4               | `vec4t()`                                               | `4 * sizeof(component)`                                            |
| Quaternion            | `quatt()`                                               | `4 * sizeof(component)`                                            |
| Transform2D           | `transform2t()`                                         | `6 * sizeof(component)`                                            |
| Transform3D           | `transform3t()`                                         | `12 * sizeof(component)`                                           |
| Normalized Vector2    | `normal2t()`                                            | `sizeof(component)`                                                |
| Normalized Vector3    | `normal3t()`                                            | `2 * sizeof(component)`                                            |

### Collections and others

| Type                  | Methods                                                 | Size                                                               |
|-----------------------|---------------------------------------------------------|--------------------------------------------------------------------|
| Arrays                | `array_of()`                                            | `sizeof(size) + array.size() * sizeof(item)`                       |
| Dictionaries          | `dictionary()`                                          | `sizeof(size) + dictionary.size() * (sizeof(key) + sizeof(value))` |
| Strings               | `string()`                                              | Size in UTF-8 + null-terminator at the end                         |
| Variant               | `variant()`                                             | Same as [var_to_bytes()]                                           |

## Implementing a custom serializer

Custom serializers are also supported. To implement one, extend the
`NetworkSchemaSerializer` class, and implement the `encode()` and `decode()`
methods.

For example, consider a `Node` serializer that encodes the node's path:

```gdscript
--8<-- "examples/snippets/network-schemas/example-node-serializer.gd"
```

This custom serializer can now be used in schemas:

```gdscript
rollback_synchronizer.set_schema({
  "Input:target": ExampleNodeSerializer.new()
})
```


[Binary serialization API]: https://docs.godotengine.org/en/stable/tutorials/io/binary_serialization_api.html
[RollbackSynchronizer]: ../nodes/rollback-synchronizer.md
[StateSynchronizer]: ../nodes/state-synchronizer.md
[var_to_bytes()]: https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-method-var-to-bytes
