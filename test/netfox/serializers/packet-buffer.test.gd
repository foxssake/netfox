extends VestTest

func get_suite_name():
	return "_PacketBuffer"

func test_should_return_single():
	var packet_buffer := _PacketBuffer.new()
	packet_buffer.max_packet_size = 16

	packet_buffer.push(chunk_of_size(15))

	var packets := packet_buffer.finish()

	expect_equal(packets.size(), 1)
	expect_equal(packets[0].size(), 15)

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
	expect_equal(packets[0].size(), 15)
	expect_equal(packets[1].size(), 6)

func test_should_keep_oversized_chunk():
	var packet_buffer := _PacketBuffer.new()
	packet_buffer.max_packet_size = 16

	packet_buffer.push(chunk_of_size(24))
	packet_buffer.push(chunk_of_size(6))

	var packets := packet_buffer.finish()

	expect_equal(packets.size(), 2)
	expect_equal(packets[0].size(), 24)
	expect_equal(packets[1].size(), 6)

func test_should_be_disabled():
	var packet_buffer := _PacketBuffer.new()
	packet_buffer.max_packet_size = 0

	packet_buffer.push(chunk_of_size(1024))
	packet_buffer.push(chunk_of_size(2048))

	var packets := packet_buffer.finish()

	expect_equal(packets.size(), 1)
	expect_equal(packets[0].size(), 3072)

func test_should_run_packet_setup():
	var buffers_setup := []
	var setup := func(buffer: StreamPeerBuffer):
		buffers_setup.append(buffer)

	var packet_buffer := _PacketBuffer.new()
	packet_buffer.packet_setup = setup
	packet_buffer.push(chunk_of_size(16))
	packet_buffer.finish()

	expect_equal(buffers_setup.size(), 1)

func chunk_of_size(size: int) -> PackedByteArray:
	var chunk := PackedByteArray()
	chunk.resize(size)
	chunk.fill(0xef)
	return chunk
