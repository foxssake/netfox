extends RefCounted
class_name _Graph

# TODO: Optimize with caches
var _links := [] as Array[Link]

func link(from: Variant, to: Variant) -> void:
	if has_link(from, to):
		return
	_links.append(Link.new(from, to))

func unlink(from: Variant, to: Variant) -> void:
	for i in _links.size():
		var link := _links[i]
		if link.from == from and link.to == to:
			_links.remove_at(i)
			break

func erase(node: Variant) -> void:
	# TODO: Measure if recreating the links is faster or if it's faster in-place
	var filtered_links := [] as Array[Link]

	for link in _links:
		if link.from == node or link.to == node:
			continue
		filtered_links.append(link)

	_links = filtered_links

func get_linked_from(from: Variant) -> Array:
	var result := []

	for link in _links:
		if link.from == from:
			result.append(link.to)

	return result

func get_linked_to(to: Variant) -> Array:
	var result := []

	for link in _links:
		if link.to == to:
			result.append(link.from)

	return result

func has_link(from: Variant, to: Variant) -> bool:
	for link in _links:
		if link.from == from and link.to == to:
			return true
	return false

class Link:
	var from: Variant
	var to: Variant

	func _init(p_from: Variant, p_to: Variant):
		from = p_from
		to = p_to
