extends VestTest

func get_suite_name():
	return "_PacketBuffer"

func test_should_return_single():
	var packet_buffer := _PacketBuffer.new()
	packet_buffer.max_packet_size = 16

	packet_buffer.push(chunk_of_size(15))

	var packets := packet_buffer.finish()

	expect_equal(packets.size(), 1)

func test_should_return_none():
	var packet_buffer := _PacketBuffer.new()
	expect_empty(packet_buffer.finish())

func test_should_return_multiple():
	var packet_buffer := _PacketBuffer.new()
	packet_buffer.max_packet_size = 16

	packet_buffer.push(chunk_of_size(15))
	packet_buffer.push(chunk_of_size(6))

	var packets := packet_buffer.finish()

	expect_equal(packets.size(), 2)

func test_should_keep_oversized_chunk():
	var packet_buffer := _PacketBuffer.new()
	packet_buffer.max_packet_size = 16

	packet_buffer.push(chunk_of_size(24))
	packet_buffer.push(chunk_of_size(6))

	var packets := packet_buffer.finish()

	expect_equal(packets.size(), 2)

func chunk_of_size(size: int) -> PackedByteArray:
	var chunk := PackedByteArray()
	chunk.resize(size)
	chunk.fill(0xef)
	return chunk
