extends RefCounted
class_name _PacketBuffer

# Packs data chunks into packets of a specified size. Multiple chunks may go
# into a single packet, as long as they fit `max_packet_size`.

var max_packet_size := 1440
var packets := [] as Array[PackedByteArray]
var packet_setup: Callable = _noop_packet_setup

var _buffer: StreamPeerBuffer = null

static var _logger := NetfoxLogger._for_netfox("PacketBuffer")

func _init(p_max_packet_size: int = 1440):
	max_packet_size = p_max_packet_size

func push(data: PackedByteArray) -> void:
	if _needs_new_packet(data):
		if _buffer != null and _buffer.get_size() > 0:
			packets.append(_buffer.data_array)
		_buffer = StreamPeerBuffer.new()
		packet_setup.call(_buffer)

	_buffer.put_data(data)

func finish() -> Array[PackedByteArray]:
	if _buffer != null and _buffer.get_size() > 0:
		packets.append(_buffer.data_array)

	var result := packets.duplicate()
	packets.clear()

	return result

func _noop_packet_setup(packet: StreamPeerBuffer) -> void:
	pass

func _needs_new_packet(incoming: PackedByteArray) -> bool:
	if _buffer == null:
		return true
	if max_packet_size <= 0:
		return false
	if incoming.size() > max_packet_size:
		_logger.warning("Buffer of %d bytes exceeds packet limit of %d; packet may be dropped", [incoming.size(), max_packet_size])
		return true
	if _buffer.get_size() + incoming.size() > max_packet_size:
		return true
	return false
