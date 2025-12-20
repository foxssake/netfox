extends RefCounted
class_name NetworkSchemaSerializer

## Base class for serializers, to use with [NetworkSchemas]
##
## Each serializer must be able to encode and decode values passed to it.
## Data is stored in [StreamPeerBuffer] objects.
## [br][br]
## To implement a custom serializer, extend this class and pass an instance of
## it in place of a NetworkSchemaSerializer, for example to [method
## RollbackSynchronizer.set_schema].
##
## @tutorial(Network schemas): https://foxssake.github.io/netfox/latest/netfox/guides/network-schemas/

## Encode [param value] into [param buffer]
func encode(value: Variant, buffer: StreamPeerBuffer) -> void:
	pass

## Decode a value from [param buffer] and return it
func decode(buffer: StreamPeerBuffer) -> Variant:
	return null
