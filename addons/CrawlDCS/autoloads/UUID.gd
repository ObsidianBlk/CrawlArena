@tool
extends Node


const LOW_BYTE : int = 0xFF

func _rng() -> int:
	randomize()
	return randi() & LOW_BYTE

func _packedbytearray_to_uuid(gen : Callable) -> StringName:
	var bin : PackedByteArray = gen.call()
	return StringName("%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x"%[
		bin[0], bin[1], bin[2], bin[3],
		bin[4], bin[5],
		bin[6], bin[7],
		bin[8], bin[9],
		bin[10], bin[11], bin[12], bin[13], bin[14], bin[15]
	])

# ----------------------
# UUID v4

func bin4() -> PackedByteArray:
	return PackedByteArray([
		_rng(), _rng(), _rng(), _rng(),
		_rng(), _rng(),
		(_rng() & 0x0F) | 0x4F, _rng(),
		_rng(), _rng(),
		_rng(), _rng(), _rng(), _rng(), _rng(), _rng()
	])

func v4() -> StringName:
	return _packedbytearray_to_uuid(bin4)
#	var bin : PackedByteArray = bin4()
#	return StringName("%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x"%[
#		bin[0], bin[1], bin[2], bin[3],
#		bin[4], bin[5],
#		bin[6], bin[7],
#		bin[8], bin[9],
#		bin[10], bin[11], bin[12], bin[13], bin[14], bin[15]
#	])


# ----------------------
# UUID v7

# v7 Calculations adapted from...
# https://gist.github.com/fabiolimace/6db9747f83b02e62db55afed8461ee5b
# and
# https://github.com/stevesimmons/uuid7-csharp
#
# Additional Reading...
# https://blog.devgenius.io/analyzing-new-unique-identifier-formats-uuidv6-uuidv7-and-uuidv8-d6cc5cd7391a
# and
# https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format#name-uuid-version-7

var _v7seq : int = 0
var _prevts : float = 0

func bin7(ts = null) -> PackedByteArray:
	if typeof(ts) != TYPE_FLOAT:
		ts = Time.get_unix_time_from_system()
		_v7seq = randi() if _prevts != ts else (_v7seq << 1) & 1
	
	var pba : PackedByteArray = PackedByteArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
	var i : int = int(ts)
	var f : int = int((ts - i) * (10 ** 9))
	
	pba.encode_u32(0, i & 0xFFFFFFFF)
	pba.encode_u16(4, (((i >> 32) & 0xF) | (f << 4)) & 0xFFFF)
	pba.encode_u16(6, ((f >> 12) & 0xFF0F) | 0x0070)
	pba.encode_u16(8, 0x20 | (_v7seq << 2)) # Figure out Sequence Number
	pba.encode_u16(10, randi())
	pba.encode_u32(12, randi())
	
	return pba

func v7(ts = null) -> StringName:
	return _packedbytearray_to_uuid(bin7.bind(ts))
