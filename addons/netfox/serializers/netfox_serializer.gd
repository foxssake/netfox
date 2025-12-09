extends RefCounted
class_name NetfoxSerializer

func encode(value: Variant, buffer: StreamPeerBuffer) -> void:
	pass

func decode(buffer: StreamPeerBuffer) -> Variant:
	return null