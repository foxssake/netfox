extends RefCounted
class_name NetworkClockSample

var ping_sent: float
var ping_received: float
var pong_sent: float
var pong_received: float

func get_rtt() -> float:
	return pong_received - ping_sent

func get_offset() -> float:
	# See: https://datatracker.ietf.org/doc/html/rfc5905#section-8
	# See: https://support.huawei.com/enterprise/en/doc/EDOC1100278232/729da750/ntp-fundamentals
	return ((ping_received - ping_sent) + (pong_sent - pong_received)) / 2.
