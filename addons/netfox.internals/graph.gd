extends RefCounted
class_name _Graph

var _links_from := {} # `from` to `to[]`
var _links_to := {} # `to` to `from[]`

func link(from: Variant, to: Variant) -> void:
	if has_link(from, to):
		return

	_append(_links_from, from, to)
	_append(_links_to, to, from)

func unlink(from: Variant, to: Variant) -> void:
	_erase(_links_from, from, to)
	_erase(_links_to, to, from)

func erase(node: Variant) -> void:
	var links_to := _links_from.get(node, [])
	var links_from := _links_to.get(node, [])

	_links_from.erase(node)
	_links_to.erase(node)

	for link in links_to:
		_erase(_links_to, link, node)

	for link in links_from:
		_erase(_links_from, link, node)

func get_linked_from(from: Variant) -> Array:
	return _links_from.get(from, [])

func get_linked_to(to: Variant) -> Array:
	return _links_to.get(to, [])

func has_link(from: Variant, to: Variant) -> bool:
	return get_linked_from(from).has(to)

func _append(pool: Dictionary, key: Variant, value: Variant) -> void:
	if not pool.has(key):
		pool[key] = [value]
	else:
		pool[key].append(value)

func _erase(pool: Dictionary, key: Variant, value: Variant) -> void:
	if not pool.has(key):
		return

	var values := pool[key] as Array
	values.erase(value)

	if values.is_empty():
		pool.erase(key)
