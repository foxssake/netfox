# Configuring properties from code

In netfox, there are multiple nodes that accept [property paths] as their
configuration, for various purposes. These can be configured as lists of
strings in the editor.

In bigger projects, with many scenes and deeper class trees, manually
configuring property paths may be tedious and unscaleable. Potentially, there
may be cases where these properties are only known at runtime, not when working
in the Editor.

There are solutions for both cases.

## Adding properties from code

Properties can be added at run-time with the following methods:

* `TickInterpolator::add_property(node, property)`
* `StateSynchronizer::add_state(node, property)`
* `RollbackSynchronizer::add_state(node, property)`
* `RollbackSynchronizer::add_input(node, property)`

*node* is a reference to a node - it may be a *string* or a *[NodePath]*
pointing to an existing node, or a *[Node]* instance. When using paths, the
path itself is considered relative to the configured *root* node.

After calling any of the methods above, calling `process_settings()` is not
necessary - it will be called automatically.

!!! warning
    The same as with `process_settings()`, configuration changes are not
    synchronized automatically! You, the developer, must ensure that
    configuration changes happen on all peers, at the same time.

    Changing state- and input property configurations is not recommended during
    gameplay.

## Adding properties automatically, in the editor

You can ensure that certain properties are added to netfox's nodes'
configuration by making your class a `@tool` script, and implementing the
following methods:

* TickInterpolator: `_get_interpolated_properties()`
* StateSynchronizer: `_get_synchronized_state_properties()`
* RollbackSynchronizer:
  * `_get_rollback_state_properties()` for state
  * `_get_rollback_input_properties()` for input

These must return an array, with each element being a string, or a two-element
array.

Strings are interpreted as property names.

Arrays are interpreted as node-property pairs. Similarly to the `add_*`
methods, the *node* may be a string, a [NodePath], or an actual [Node]
instance. When using strings or [NodePath]s, keep in mind that the path is
considered *relative to the node itself, not the configured root*.

Each of these nodes will explore nodes under their `root` node, and call the
above methods if implemented. The results will be added to the node
configuration.

This exploration is implemented in the nodes' `_get_configuration_warnings()`
method, which is called when the node tree changes ( i.e. nodes are added /
removed ), and when opening the scene.

The exploration also runs when before saving the scene, to make sure that any
updates are picked up.

!!! tip
    To make sure that the updated methods are picked up, save your scene. The
    exploration is ran before every scene save.

An example implementation for the above methods:

```gdscript
func _get_interpolated_properties():
	# Specify a list of properties
	return ["position", "quaternion"]

func _get_synchronized_state_properties() -> Array:
	# Specify inherited properties and more
	return super() + [
		"health", "name",
		[weapon, "ammo"],		# Specify a property on another node
		["Hand/Weapon", "ammo"]	# Specify node by path
	]

func _get_rollback_state_properties() -> Array:
	return [
		"transform",			# Specify a property on self
		[weapon, "ammo"]		# Specify a property on another node
	]

func _get_rollback_input_propertes() -> Array:
	# Specify a list of properties
	return ["movement", "is_jumping"]
```

See the [Property configuration example].

!!! note
    In general, it's best practice to only specify node's own properties. An
    exception is when the given node has no script attached.

### Caveats

**Node renames and removals** are not tracked. Unless fixed manually, they will
result in invalid property warnings.

A workaround is to reset the node's state/input/property configuration to an
empty array and save again. This will gather the tracked properties with the
right node names.

[property paths]: ../guides/property-paths.md
[NodePath]: https://docs.godotengine.org/en/stable/classes/class_nodepath.html
[Node]: https://docs.godotengine.org/en/stable/classes/class_node.html
[Property configuration example]: https://github.com/foxssake/netfox/tree/main/examples/property-configuration
